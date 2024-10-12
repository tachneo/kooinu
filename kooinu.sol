// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title KooInu (KOO) Smart Contract
 * @dev ERC20 Token with Fee Management, Automated Liquidity Provision, Staking with Reward Pool,
 * Enhanced Security Features, Governance Mechanisms, and a Buyback Reward system.
 */

/// @notice Context provides information about the current execution context.
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }
}

/// @notice Ownable contract module which provides basic access control mechanism.
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }   
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
        
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/// @notice IERC20 interface defines the standard functions and events for ERC20 tokens.
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);

    // ERC20 Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);
}

/// @notice Address library provides utility functions related to the address type.
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * IMPORTANT: It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * IMPORTANT: Because control is transferred to `recipient`, care must be taken
     * to not create reentrancy vulnerabilities.
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // Perform the call and check for success
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: ETH transfer failed");
    }
}

/// @notice ReentrancyGuard contract to prevent reentrant calls.
abstract contract ReentrancyGuard {
    uint256 private _status;
    
    constructor () {
        _status = 1;
    }
    
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Applying the nonReentrant modifier to functions ensures that there are no nested (reentrant) calls to them.
     */
    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");
        
        _status = 2;
        
        _;
        
        _status = 1;
    }
}

/// @notice Interface for the Uniswap V2 Factory.
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

/// @notice Interface for the Uniswap V2 Router02.
interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    // Swap functions
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    // Liquidity functions
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    // Get amounts out for swaps
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

/// @notice Main contract implementing the ERC20 token with additional features.
contract KooInu is Context, IERC20, Ownable, ReentrancyGuard {
    using Address for address payable;

    // ----------------- Token Details -----------------
    string private constant _name = "KooInu";
    string private constant _symbol = "KOO";
    uint8 private constant _decimals = 9;

    // ----------------- Wallet Addresses -----------------
    address payable public marketingWalletAddress;
    address payable public teamWalletAddress;
    address public immutable deadAddress = address(0xdead); // Dead address for burning tokens

    // ----------------- Mappings -----------------
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
        
    // Mappings to manage fee and limit exemptions
    mapping (address => bool) public isExcludedFromFee;
    mapping (address => bool) public isWalletLimitExempt;
    mapping (address => bool) public isTxLimitExempt;
    mapping (address => bool) public isMarketPair;

    // ----------------- Fee Parameters (Basis Points) -----------------
    // Fees for buying
    uint256 public _buyLiquidityFeeBP = 200; // 2%
    uint256 public _buyMarketingFeeBP = 200; // 2%
    uint256 public _buyTeamFeeBP = 200; // 2%
    uint256 public _buyBuybackFeeBP = 100; // 1%
        
    // Fees for selling
    uint256 public _sellLiquidityFeeBP = 200; // 2%
    uint256 public _sellMarketingFeeBP = 200; // 2%
    uint256 public _sellTeamFeeBP = 400; // 4%
    uint256 public _sellBuybackFeeBP = 100; // 1%

    // Distribution shares
    uint256 public _liquidityShareBP = 400; // 4%
    uint256 public _marketingShareBP = 400; // 4%
    uint256 public _teamShareBP = 1600; // 16%
    uint256 public _buybackShareBP = 600; // 6%

    // Total taxes
    uint256 public _totalTaxIfBuyingBP;
    uint256 public _totalTaxIfSellingBP;
    uint256 public _totalDistributionSharesBP;

    // ----------------- Supply and Limits -----------------
    uint256 private constant _totalSupply = 1000000000000000 * (10 ** _decimals);
    uint256 public _maxTxAmount = _totalSupply; 
    uint256 public _walletMax = _totalSupply;
    uint256 private minimumTokensBeforeSwap = _totalSupply / 100; // 1% of total supply

    // Maximum fee limits
    uint256 public constant MAX_TOTAL_FEE_BP = 2000; // Maximum total fee is 20%
    uint256 public constant MAX_INDIVIDUAL_FEE_BP = 1000; // Maximum individual fee is 10%

    // Minimum and maximum transaction and wallet limits
    uint256 public minTxAmount = _totalSupply / 10000; // Minimum 0.01% of total supply
    uint256 public maxTxAmountCap = _totalSupply; // Max is total supply
    uint256 public minWalletLimit = _totalSupply / 10000; // Minimum 0.01% of total supply
    uint256 public maxWalletLimit = _totalSupply; // Max is total supply

    // ----------------- Uniswap Router and Pair -----------------
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;
        
    // Flags for swap and liquify functionality
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public swapAndLiquifyByLimitOnly = false;
    bool public checkWalletLimit = true;

    // Swap limits
    uint256 public maxSwapAmount = _totalSupply / 200; // 0.5% of total supply

    // ----------------- Events -----------------
    // Swap and Liquify Events
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
        
    // Swap Events
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
        
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );
        
    // Withdrawal Events
    event EtherWithdrawn(address indexed owner, uint256 amount);
    event ERC20Withdrawn(address indexed owner, address indexed token, uint256 amount);
        
    // Enhanced Access Control Events
    event MarketPairStatusUpdated(address indexed account, bool newValue);
    event TxLimitExemptStatusUpdated(address indexed holder, bool exempt);
    event FeeExemptionStatusUpdated(address indexed account, bool newValue);
    event BuyTaxesUpdated(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP, uint256 buybackFeeBP);
    event SellTaxesUpdated(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP, uint256 buybackFeeBP);
    event DistributionSettingsUpdated(uint256 liquidityShareBP, uint256 marketingShareBP, uint256 teamShareBP, uint256 buybackShareBP);
    event MaxTxAmountUpdated(uint256 maxTxAmount);
    event WalletLimitEnabled(bool enabled);
    event WalletLimitExemptStatusUpdated(address indexed holder, bool exempt);
    event WalletLimitUpdated(uint256 newLimit);
    event NumTokensBeforeSwapUpdated(uint256 newLimit);
    event SwapAndLiquifyByLimitOnlyUpdated(bool newValue);

    // ----------------- Modifiers -----------------
    /// @dev Modifier to prevent reentrancy during swap and liquify.
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    // ----------------- Staking Variables -----------------
    struct StakeInfo {
        uint256 amount;          // Amount of tokens staked
        uint256 rewardDebt;      // Reward debt
        uint256 lastStakeTime;   // Last time tokens were staked or rewards were claimed
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    uint256 public rewardRatePerSecond; // Adjusted reward rate per second based on APR
    uint256 public constant MAX_REWARD_RATE = 100; // Maximum reward rate per second (percentage per annum)
    uint256 public stakingStartTime;

    // Reward Pool
    uint256 public stakingRewardPool;
    uint256 public totalRewardsDistributed;
    uint256 public maxTotalRewards;

    // Staking Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    // ----------------- Governance Variables -----------------
    uint256 public constant GOVERNANCE_DELAY = 1 days; // Time delay for executing proposals
    uint256 public constant PROPOSAL_EXPIRY_PERIOD = 7 days; // Proposal expiry time

    uint256 public constant MIN_SIGNATURES = 2; // Minimum number of approvals required
    mapping(address => bool) public isSigner;
    address[] public signers;

    struct Proposal {
        uint256 id;
        ProposalType proposalType;
        address proposer;
        uint256 newValue;
        uint256 proposedTime;
        uint256 executeTime;
        uint256 expiryTime;
        uint256 approvalCount;
        bool executed;
    }

    enum ProposalType { RewardRateChange, FeeChange }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public proposalApprovals; // Tracks approvals for each proposal

    // Governance Events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address indexed proposer, uint256 newValue, uint256 executeTime, uint256 expiryTime);
    event ProposalApproved(uint256 indexed proposalId, address indexed approver);
    event ProposalRevoked(uint256 indexed proposalId, address indexed revoker);
    event ProposalExecuted(uint256 indexed proposalId, uint256 newValue);
    
    // ----------------- Constructor -----------------
    // Declaration of the initial signers array
    address[] private initialSigners; // Declare the initial signers array    
    /**
     * @dev Constructor to initialize the contract with multiple initial signers.
     */
    constructor () ReentrancyGuard() {
        // Set the marketing and team wallet addresses
        marketingWalletAddress = payable(0x7184eAC82c0C3F6bcdFD1c28A508dC4a18120b1e); // Marketing Address
        teamWalletAddress = payable(0xa26809d31cf0cCd4d11C520F84CE9a6Fc4d4bb75); // Team Address
            
        // Initialize Uniswap router with the specified address
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E // Example: PancakeSwap Router on BSC
        ); 

        // Create a Uniswap pair for this token
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // Set the Uniswap router
        uniswapV2Router = _uniswapV2Router;
        // Approve the Uniswap router to spend the total supply of tokens
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        // Exclude owner and contract from fee
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
            
        // Calculate total taxes for buying and selling
        _totalTaxIfBuyingBP = _buyLiquidityFeeBP + _buyMarketingFeeBP + _buyTeamFeeBP + _buyBuybackFeeBP;
        _totalTaxIfSellingBP = _sellLiquidityFeeBP + _sellMarketingFeeBP + _sellTeamFeeBP + _sellBuybackFeeBP;
        _totalDistributionSharesBP = _liquidityShareBP + _marketingShareBP + _teamShareBP + _buybackShareBP;

        // Exempt owner, Uniswap pair, and contract from wallet limit
        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[uniswapPair] = true;
        isWalletLimitExempt[address(this)] = true;
            
        // Exempt owner and contract from transaction limit
        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        // Mark the Uniswap pair as a market pair
        isMarketPair[uniswapPair] = true;

        // Initialize staking reward pool
        stakingRewardPool = _totalSupply * 10 / 100; // Allocate 10% for staking rewards
        _balances[address(this)] = stakingRewardPool;
        emit Transfer(address(0), address(this), stakingRewardPool);

        uint256 ownerBalance = _totalSupply - stakingRewardPool;
        _balances[_msgSender()] = ownerBalance;
        emit Transfer(address(0), _msgSender(), ownerBalance);

        maxTotalRewards = stakingRewardPool;

        // Initialize reward rate per second based on an annual rate
        uint256 annualRate = 10; // 10% annual rate
        uint256 secondsInYear = 31536000; // Number of seconds in a year
        rewardRatePerSecond = (annualRate * 1e18) / secondsInYear;

        // Initialize governance signers with multiple initial signers
        initialSigners[0] = _msgSender();
        initialSigners[1] = address(0x5EE2a5C3cf8dFFd634C89b275A0C8C88f68Fc9B9); // Replace with actual addresses
        initialSigners[2] = address(0x10f7baf7abB2c3238deffab982abAc5e4C6FBb66);

        uint256 len = initialSigners.length;
        for(uint256 i = 0; i < len; ) {
            address signer = initialSigners[i];
            require(signer != address(0), "KOO: Zero address cannot be a signer");
            require(!isSigner[signer], "KOO: Signer already added");
            isSigner[signer] = true;
            signers.push(signer);
            emit SignerAdded(signer);
            unchecked { i++; }
        }
    }



    // ----------------- ERC20 Standard Functions -----------------
    
    /**
     * @dev Returns the name of the token.
     */
    function name() public pure returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the total supply of the token.
     */
    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the balance of a specific account.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Returns the allowance of a spender for a specific owner.
     */
    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    /**
     * @dev Approves a spender to spend a specified amount of tokens on behalf of the caller.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), "KOO: approve zero address");
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Internal function to handle approvals.
     */
    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "KOO: approve from zero address"); // Prevent approving from the zero address
        require(spender != address(0), "KOO: approve to zero address"); // Prevent approving to the zero address

        _allowances[owner_][spender] = amount; // Set the allowance
        emit Approval(owner_, spender, amount); // Emit Approval event
    }

    /**
     * @dev Increases the allowance of a spender.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0), "KOO: increase allowance zero address");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Decreases the allowance of a spender.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0), "KOO: decrease allowance zero address");
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "KOO: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    /**
     * @dev Returns the minimum number of tokens required before a swap can occur.
     */
    function minimumTokensBeforeSwapAmount() public view returns (uint256) {
        return minimumTokensBeforeSwap;
    }

    /**
     * @dev Transfers tokens to a specified address.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another using the allowance mechanism.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(_allowances[sender][_msgSender()] >= amount, "KOO: transfer amount exceeds allowance");
        _transfer(sender, recipient, amount);
        // Decrease the allowance accordingly
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    // ----------------- Internal Transfer Function -----------------
    
    /**
     * @dev Internal function to handle transfers, including fee logic and swap & liquify.
     */
    function _transfer(address sender, address recipient, uint256 amount) private nonReentrant returns (bool) {

        require(sender != address(0), "KOO: transfer from zero address"); // Prevent transfer from zero address
        require(recipient != address(0), "KOO: transfer to zero address"); // Prevent transfer to zero address

        if(inSwapAndLiquify) { 
            return _basicTransfer(sender, recipient, amount); // If already in swap and liquify, perform a basic transfer
        }
        else {
            if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
                require(amount <= _maxTxAmount, "KOO: exceeds maxTxAmount."); // Enforce max transaction limit
            }            

            uint256 contractTokenBalance = _balances[address(this)]; // Get the contract's token balance
            bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;
                
            // Check if conditions are met to perform swap and liquify
            if (overMinimumTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) 
            {
                if(swapAndLiquifyByLimitOnly)
                    contractTokenBalance = minimumTokensBeforeSwap; // Use minimum tokens if swap by limit only
                else if(contractTokenBalance > maxSwapAmount)
                    contractTokenBalance = maxSwapAmount; // Limit the swap to prevent high slippage

                swapAndLiquify(contractTokenBalance); // Perform swap and liquify
            }

            // Subtract the amount from the sender's balance
            _balances[sender] -= amount;

            // Calculate the final amount after deducting fees if applicable
            uint256 finalAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ? 
                                         amount : takeFee(sender, recipient, amount);

            // Check wallet limit if applicable
            if(checkWalletLimit && !isWalletLimitExempt[recipient])
                require(_balances[recipient] + finalAmount <= _walletMax, "KOO: exceeds max wallet limit");

            // Add the final amount to the recipient's balance
            _balances[recipient] += finalAmount;

            emit Transfer(sender, recipient, finalAmount); // Emit the transfer event
            return true;
        }
    }

    /**
     * @dev Performs a basic transfer without taking any fees.
     */
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] -= amount; // Subtract from sender
        _balances[recipient] += amount; // Add to recipient
        emit Transfer(sender, recipient, amount); // Emit transfer event
        return true;
    }

    /**
     * @dev Takes fee on transactions based on whether it's a buy or sell.
     */
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;
            
        if(isMarketPair[sender]) {
            feeAmount = amount * _totalTaxIfBuyingBP / 10000; // Calculate buy fee
        }
        else if(isMarketPair[recipient]) {
            feeAmount = amount * _totalTaxIfSellingBP / 10000; // Calculate sell fee
        }
            
        if(feeAmount > 0) {
            _balances[address(this)] += feeAmount; // Add fee to contract balance
            emit Transfer(sender, address(this), feeAmount); // Emit transfer event for fee
        }

        return amount - feeAmount; // Return the amount after fee deduction
    }

    // ----------------- Swap and Liquify Functions -----------------
    
    /**
     * @dev Handles swapping tokens for ETH and adding liquidity, including buyback functionality.
     */
    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        uint256 totalDistributionSharesBP = _totalDistributionSharesBP;
        uint256 liquidityShareBP = _liquidityShareBP;
        uint256 marketingShareBP = _marketingShareBP;
        uint256 teamShareBP = _teamShareBP;
        uint256 buybackShareBP = _buybackShareBP;

        // Calculate tokens for liquidity
        uint256 tokensForLP = tAmount * liquidityShareBP / totalDistributionSharesBP / 2;
        uint256 tokensForSwap = tAmount - tokensForLP; // Remaining tokens to swap

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(tokensForSwap);

        uint256 amountReceived = address(this).balance - initialBalance; // Get the ETH received from swap

        uint256 totalBNBFee = (liquidityShareBP / 2) + marketingShareBP + teamShareBP + buybackShareBP;
            
        // Calculate amounts for liquidity, team, marketing, and buyback
        uint256 amountBNBLiquidity = (amountReceived * (liquidityShareBP / 2)) / totalBNBFee;
        uint256 amountBNBTeam = (amountReceived * teamShareBP) / totalBNBFee;
        uint256 amountBNBMarketing = (amountReceived * marketingShareBP) / totalBNBFee;
        uint256 amountBNBBuyback = (amountReceived * buybackShareBP) / totalBNBFee;

        if(amountBNBMarketing > 0)
            marketingWalletAddress.transfer(amountBNBMarketing); // Transfer to marketing wallet

        if(amountBNBTeam > 0)
            teamWalletAddress.transfer(amountBNBTeam); // Transfer to team wallet

        if(amountBNBLiquidity > 0 && tokensForLP > 0)
            addLiquidity(tokensForLP, amountBNBLiquidity); // Add liquidity to Uniswap

        if(amountBNBBuyback > 0)
            buyBackTokens(amountBNBBuyback); // Perform buyback and burn
    }
        
    /**
     * @dev Swaps a specified amount of tokens for ETH using Uniswap.
     */
    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve the router to spend tokens

        // Get expected ETH amount to set as amountOutMin for slippage protection
        uint256[] memory amountsOut = uniswapV2Router.getAmountsOut(tokenAmount, path);
        uint256 amountOutMin = (amountsOut[1] * 95) / 100; // Accept at least 95% of expected ETH

        // Make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            amountOutMin, // Slippage protection
            path,
            address(this), // The contract
            block.timestamp
        );
        
        emit SwapTokensForETH(tokenAmount, path); // Emit event after swap
    }

    /**
     * @dev Swaps ETH for tokens and burns them (buyback).
     */
    function buyBackTokens(uint256 amount) private lockTheSwap {
        if(amount > 0){
            address[] memory path = new address[](2);
            path[0] = uniswapV2Router.WETH();
            path[1] = address(this);

            // Get expected token amount to set as amountOutMin for slippage protection
            uint256[] memory amountsOut = uniswapV2Router.getAmountsOut(amount, path);
            uint256 amountOutMin = (amountsOut[1] * 95) / 100; // Accept at least 95% of expected tokens

            // Execute the swap
            uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
                amountOutMin, // Slippage protection
                path,
                deadAddress, // Send tokens to dead address (burn)
                block.timestamp
            );

            emit SwapETHForTokens(amount, path);
        }
    }

    /**
     * @dev Adds liquidity to Uniswap using the specified token and ETH amounts.
     */
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve token transfer to the router

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // Slippage is unavoidable
            0, // Slippage is unavoidable
            owner(),
            block.timestamp
        );

        emit SwapAndLiquify(tokenAmount, ethAmount, tokenAmount);
    }

    /**
     * @dev Transfers Ether to a specified address.
     */
    function transferToAddressETH(address payable recipient, uint256 amount) private {
        recipient.sendValue(amount);
    }

    // Function to receive ETH from UniswapV2Router when swapping
    receive() external payable {}

    // ----------------- Administrative Functions -----------------
    
    /**
     * @dev Sets the market pair status for a specific account.
     */
    function setMarketPairStatus(address account, bool newValue) public onlyOwner {
        isMarketPair[account] = newValue;
        emit MarketPairStatusUpdated(account, newValue);
    }

    /**
     * @dev Sets the transaction limit exemption status for a holder.
     */
    function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
        emit TxLimitExemptStatusUpdated(holder, exempt);
    }
        
    /**
     * @dev Sets the fee exemption status for a specific account.
     */
    function setIsExcludedFromFee(address account, bool newValue) public onlyOwner {
        isExcludedFromFee[account] = newValue;
        emit FeeExemptionStatusUpdated(account, newValue);
    }

    /**
     * @dev Sets the buy taxes: liquidity, marketing, team, and buyback fees.
     * Can only be called via governance proposals.
     */
    function setBuyTaxes(uint256 newLiquidityFeeBP, uint256 newMarketingFeeBP, uint256 newTeamFeeBP, uint256 newBuybackFeeBP) external {
        require(msg.sender == address(this), "KOO: Only via governance");
        require(newLiquidityFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Liquidity fee too high");
        require(newMarketingFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Marketing fee too high");
        require(newTeamFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Team fee too high");
        require(newBuybackFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Buyback fee too high");

        uint256 totalFeeBP = newLiquidityFeeBP + newMarketingFeeBP + newTeamFeeBP + newBuybackFeeBP;
        require(totalFeeBP <= MAX_TOTAL_FEE_BP, "KOO: Total fee too high");

        _buyLiquidityFeeBP = newLiquidityFeeBP;
        _buyMarketingFeeBP = newMarketingFeeBP;
        _buyTeamFeeBP = newTeamFeeBP;
        _buyBuybackFeeBP = newBuybackFeeBP;

        _totalTaxIfBuyingBP = _buyLiquidityFeeBP + _buyMarketingFeeBP + _buyTeamFeeBP + _buyBuybackFeeBP;

        emit BuyTaxesUpdated(newLiquidityFeeBP, newMarketingFeeBP, newTeamFeeBP, newBuybackFeeBP);
    }

    /**
     * @dev Sets the sell taxes: liquidity, marketing, team, and buyback fees.
     * Can only be called via governance proposals.
     */
    function setSellTaxes(uint256 newLiquidityFeeBP, uint256 newMarketingFeeBP, uint256 newTeamFeeBP, uint256 newBuybackFeeBP) external {
        require(msg.sender == address(this), "KOO: Only via governance");
        require(newLiquidityFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Liquidity fee too high");
        require(newMarketingFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Marketing fee too high");
        require(newTeamFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Team fee too high");
        require(newBuybackFeeBP <= MAX_INDIVIDUAL_FEE_BP, "KOO: Buyback fee too high");

        uint256 totalFeeBP = newLiquidityFeeBP + newMarketingFeeBP + newTeamFeeBP + newBuybackFeeBP;
        require(totalFeeBP <= MAX_TOTAL_FEE_BP, "KOO: Total fee too high");

        _sellLiquidityFeeBP = newLiquidityFeeBP;
        _sellMarketingFeeBP = newMarketingFeeBP;
        _sellTeamFeeBP = newTeamFeeBP;
        _sellBuybackFeeBP = newBuybackFeeBP;

        _totalTaxIfSellingBP = _sellLiquidityFeeBP + _sellMarketingFeeBP + _sellTeamFeeBP + _sellBuybackFeeBP;

        emit SellTaxesUpdated(newLiquidityFeeBP, newMarketingFeeBP, newTeamFeeBP, newBuybackFeeBP);
    }
        
    /**
     * @dev Sets the distribution shares for liquidity, marketing, team, and buyback.
     * Can only be called via governance proposals.
     */
    function setDistributionSettings(uint256 newLiquidityShareBP, uint256 newMarketingShareBP, uint256 newTeamShareBP, uint256 newBuybackShareBP) external {
        require(msg.sender == address(this), "KOO: Only via governance");

        _liquidityShareBP = newLiquidityShareBP;
        _marketingShareBP = newMarketingShareBP;
        _teamShareBP = newTeamShareBP;
        _buybackShareBP = newBuybackShareBP;

        _totalDistributionSharesBP = _liquidityShareBP + _marketingShareBP + _teamShareBP + _buybackShareBP;

        emit DistributionSettingsUpdated(newLiquidityShareBP, newMarketingShareBP, newTeamShareBP, newBuybackShareBP);
    }
        
    /**
     * @dev Sets the maximum transaction amount.
     */
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        require(maxTxAmount >= minTxAmount, "KOO: Max tx amount too low");
        require(maxTxAmount <= maxTxAmountCap, "KOO: Max tx amount too high");
        _maxTxAmount = maxTxAmount;
        emit MaxTxAmountUpdated(maxTxAmount);
    }

    /**
     * @dev Enables or disables the wallet limit.
     */
    function enableDisableWalletLimit(bool newValue) external onlyOwner {
       checkWalletLimit = newValue;
       emit WalletLimitEnabled(newValue);
    }

    /**
     * @dev Sets the wallet limit exemption status for a holder.
     */
    function setIsWalletLimitExempt(address holder, bool exempt) external onlyOwner {
        isWalletLimitExempt[holder] = exempt;
        emit WalletLimitExemptStatusUpdated(holder, exempt);
    }

    /**
     * @dev Sets the maximum number of tokens a wallet can hold.
     */
    function setWalletLimit(uint256 newLimit) external onlyOwner {
        require(newLimit >= minWalletLimit, "KOO: Wallet limit too low");
        require(newLimit <= maxWalletLimit, "KOO: Wallet limit too high");
        _walletMax  = newLimit;
        emit WalletLimitUpdated(newLimit);
    }

    /**
     * @dev Sets the minimum number of tokens before a swap is triggered.
     */
    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
        emit NumTokensBeforeSwapUpdated(newLimit);
    }

    /**
     * @dev Enables or disables the swap and liquify feature.
     */
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /**
     * @dev Sets whether swap and liquify should occur only when the threshold is reached.
     */
    function setSwapAndLiquifyByLimitOnly(bool newValue) public onlyOwner {
        swapAndLiquifyByLimitOnly = newValue;
        emit SwapAndLiquifyByLimitOnlyUpdated(newValue);
    }
        
    /**
     * @dev Returns the circulating supply (total supply minus the balance of the dead address).
     */
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - _balances[deadAddress];
    }

    // ----------------- Withdrawal Functions -----------------
    
    /**
     * @dev Withdraws Ether from the contract to the owner's address.
     */
    function withdrawEther(uint256 amount) external onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance >= amount, "KOO: Insufficient Ether");
        payable(owner()).transfer(amount);
        emit EtherWithdrawn(owner(), amount);
    }

    /**
     * @dev Withdraws ERC20 tokens mistakenly sent to the contract.
     */
    function withdrawERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner nonReentrant {
        require(tokenAddress != address(this), "KOO: Cannot withdraw own tokens");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit ERC20Withdrawn(owner(), tokenAddress, tokenAmount);
    }

    // ----------------- Staking Functions -----------------
    
    /**
     * @dev Allows a user to stake a specific amount of KOO tokens.
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "KOO: Cannot stake zero");
        require(_balances[msg.sender] >= amount, "KOO: Insufficient balance");
        require(stakingStartTime > 0, "KOO: Staking not started");

        // Update rewards before staking
        _updateRewards(msg.sender);

        // State changes before external interactions
        _balances[msg.sender] -= amount;
        _balances[address(this)] += amount;
        StakeInfo storage userStake = stakes[msg.sender];
        userStake.amount += amount;
        userStake.lastStakeTime = block.timestamp;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
        emit Transfer(msg.sender, address(this), amount);
    }

    /**
     * @dev Allows a user to unstake a specific amount of KOO tokens.
     */
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "KOO: Cannot unstake zero");
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "KOO: Insufficient staked");

        // Update rewards before unstaking
        _updateRewards(msg.sender);

        // State changes before external interactions
        userStake.amount -= amount;
        userStake.lastStakeTime = block.timestamp;
        totalStaked -= amount;

        // Transfer tokens back to user
        _balances[address(this)] -= amount;
        _balances[msg.sender] += amount;
        emit Transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Allows a user to claim their staking rewards.
     */
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);
        StakeInfo storage userStake = stakes[msg.sender];
        uint256 reward = userStake.rewardDebt;
        require(reward > 0, "KOO: No rewards");
        require(stakingRewardPool >= reward, "KOO: Not enough rewards");
        require(totalRewardsDistributed + reward <= maxTotalRewards, "KOO: Reward cap reached");

        // Reset reward debt before external interactions
        userStake.rewardDebt = 0;
        stakingRewardPool -= reward;
        totalRewardsDistributed += reward;

        // Transfer rewards to user
        _balances[address(this)] -= reward;
        _balances[msg.sender] += reward;
        emit Transfer(address(this), msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Internal function to update the staking rewards for a user.
     */
    function _updateRewards(address user) internal {
        StakeInfo storage userStake = stakes[user];
        if(userStake.amount > 0){
            uint256 stakingDuration = block.timestamp - userStake.lastStakeTime;
            uint256 reward = (userStake.amount * rewardRatePerSecond * stakingDuration) / 1e18;
            userStake.rewardDebt += reward;
            userStake.lastStakeTime = block.timestamp;
        }
    }

    // ----------------- Governance Functions -----------------
    
    /**
     * @dev Adds a new signer. Only callable by the owner.
     */
    function addSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "KOO: Zero address");
        require(!isSigner[newSigner], "KOO: Already a signer");
        isSigner[newSigner] = true;
        signers.push(newSigner);
        emit SignerAdded(newSigner);
    }

    /**
     * @dev Removes an existing signer. Only callable by the owner.
     */
    function removeSigner(address signer) external onlyOwner {
        require(isSigner[signer], "KOO: Not a signer");
        isSigner[signer] = false;

        // Remove signer from the signers array
        uint256 len = signers.length;
        for(uint256 i = 0; i < len; ++i) {
            if(signers[i] == signer){
                signers[i] = signers[len - 1];
                signers.pop();
                break;
            }
        }

        emit SignerRemoved(signer);
    }

    /**
     * @dev Proposes a change to the reward rate or fees. Requires multi-signature approval and a time lock.
     */
    function proposeChange(ProposalType proposalType, uint256 newValue) external onlySigner {
        require(newValue > 0, "KOO: New value zero");
        if(proposalType == ProposalType.RewardRateChange) {
            require(newValue <= MAX_REWARD_RATE, "KOO: Reward rate too high");
        } else if(proposalType == ProposalType.FeeChange) {
            require(newValue <= MAX_TOTAL_FEE_BP, "KOO: Fee too high");
        }

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposalType = proposalType;
        newProposal.proposer = msg.sender;
        newProposal.newValue = newValue;
        newProposal.proposedTime = block.timestamp;
        newProposal.executeTime = block.timestamp + GOVERNANCE_DELAY;
        newProposal.expiryTime = block.timestamp + PROPOSAL_EXPIRY_PERIOD;
        newProposal.approvalCount = 0;
        newProposal.executed = false;

        emit ProposalCreated(proposalCount, proposalType, msg.sender, newValue, newProposal.executeTime, newProposal.expiryTime);
    }

    /**
     * @dev Approves a proposal. Only signers can approve.
     */
    function approveProposal(uint256 proposalId) external onlySigner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "KOO: Proposal not exist");
        require(!proposal.executed, "KOO: Proposal executed");
        require(!proposalApprovals[proposalId][msg.sender], "KOO: Already approved");
        require(block.timestamp <= proposal.expiryTime, "KOO: Proposal expired");

        proposalApprovals[proposalId][msg.sender] = true;
        proposal.approvalCount += 1;

        emit ProposalApproved(proposalId, msg.sender);

        // If approval count reaches minimum signatures and delay passed, execute the proposal
        if(proposal.approvalCount >= MIN_SIGNATURES && block.timestamp >= proposal.executeTime) {
            executeProposal(proposalId);
        }
    }

    /**
     * @dev Revokes an approval for a proposal. Only signers can revoke.
     */
    function revokeApproval(uint256 proposalId) external onlySigner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "KOO: Proposal not exist");
        require(!proposal.executed, "KOO: Proposal executed");
        require(proposalApprovals[proposalId][msg.sender], "KOO: Approval not found");

        proposalApprovals[proposalId][msg.sender] = false;
        proposal.approvalCount -= 1;

        emit ProposalRevoked(proposalId, msg.sender);
    }

    /**
     * @dev Executes a proposal after the time lock and sufficient approvals.
     */
    function executeProposal(uint256 proposalId) public nonReentrant onlySigner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "KOO: Proposal not exist");
        require(!proposal.executed, "KOO: Proposal executed");
        require(proposal.approvalCount >= MIN_SIGNATURES, "KOO: Not enough approvals");
        require(block.timestamp >= proposal.executeTime, "KOO: Delay not passed");
        require(block.timestamp <= proposal.expiryTime, "KOO: Proposal expired");

        // Apply the proposed change based on proposal type
        if(proposal.proposalType == ProposalType.RewardRateChange) {
            // Calculate the new rewardRatePerSecond based on the annual rate
            uint256 annualRate = proposal.newValue; // e.g., 10 for 10%
            uint256 secondsInYear = 31536000; // Number of seconds in a year
            rewardRatePerSecond = (annualRate * 1e18) / secondsInYear;
        } else if(proposal.proposalType == ProposalType.FeeChange) {
            // To prevent multiple function calls via governance, set buy and sell taxes directly
            // Note: This approach assumes that newValue is structured appropriately
            // For more granular control, consider passing separate values or modifying the proposal structure

            // Example: Setting all buy and sell fees to newValue
            _buyLiquidityFeeBP = proposal.newValue;
            _buyMarketingFeeBP = proposal.newValue;
            _buyTeamFeeBP = proposal.newValue;
            _buyBuybackFeeBP = proposal.newValue;

            _totalTaxIfBuyingBP = _buyLiquidityFeeBP + _buyMarketingFeeBP + _buyTeamFeeBP + _buyBuybackFeeBP;

            _sellLiquidityFeeBP = proposal.newValue;
            _sellMarketingFeeBP = proposal.newValue;
            _sellTeamFeeBP = proposal.newValue;
            _sellBuybackFeeBP = proposal.newValue;

            _totalTaxIfSellingBP = _sellLiquidityFeeBP + _sellMarketingFeeBP + _sellTeamFeeBP + _sellBuybackFeeBP;

            emit BuyTaxesUpdated(_buyLiquidityFeeBP, _buyMarketingFeeBP, _buyTeamFeeBP, _buyBuybackFeeBP);
            emit SellTaxesUpdated(_sellLiquidityFeeBP, _sellMarketingFeeBP, _sellTeamFeeBP, _sellBuybackFeeBP);
        }

        proposal.executed = true;

        emit ProposalExecuted(proposalId, proposal.newValue);
    }

    /**
     * @dev Modifier to restrict access to only authorized signers.
     */
    modifier onlySigner() {
        require(isSigner[msg.sender], "KOO: Caller not signer");
        _;
    }

    // ----------------- Additional Administrative Functions -----------------
    
    /**
     * @dev Allows the owner to set the marketing wallet address.
     */
    function setMarketingWalletAddress(address payable newMarketingWallet) external onlyOwner {
        require(newMarketingWallet != address(0), "KOO: Zero address");
        marketingWalletAddress = newMarketingWallet;
        emit MarketingWalletUpdated(newMarketingWallet);
    }

    /**
     * @dev Allows the owner to set the team wallet address.
     */
    function setTeamWalletAddress(address payable newTeamWallet) external onlyOwner {
        require(newTeamWallet != address(0), "KOO: Zero address");
        teamWalletAddress = newTeamWallet;
        emit TeamWalletUpdated(newTeamWallet);
    }

    /**
     * @dev Allows the owner to set the staking start time.
     */
    function setStakingStartTime(uint256 timestamp) external onlyOwner {
        stakingStartTime = timestamp;
        emit StakingStartTimeUpdated(timestamp);
    }

    // ----------------- Events for Additional Administrative Functions -----------------
    
    /**
     * @dev Emitted when the marketing wallet address is updated.
     */
    event MarketingWalletUpdated(address newMarketingWallet);

    /**
     * @dev Emitted when the team wallet address is updated.
     */
    event TeamWalletUpdated(address newTeamWallet);

    /**
     * @dev Emitted when the staking start time is updated.
     */
    event StakingStartTimeUpdated(uint256 newTimestamp);

    // ----------------- Staking Initialization -----------------
    
    /**
     * @dev Initializes the staking reward pool. Can only be called once by the owner.
     */
    function initializeStakingPool() external onlyOwner {
        require(stakingStartTime == 0, "KOO: Staking initialized");
        stakingRewardPool = _totalSupply * 10 / 100; // Allocate 10% for staking rewards
        _balances[address(this)] += stakingRewardPool;
        emit Transfer(address(0), address(this), stakingRewardPool);
        maxTotalRewards = stakingRewardPool;
        stakingStartTime = block.timestamp;
    }

    // ----------------- Governance Helper Functions -----------------
    
    /**
     * @dev Returns the list of current signers.
     */
    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    /**
     * @dev Returns the details of a specific proposal.
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        ProposalType proposalType,
        address proposer,
        uint256 newValue,
        uint256 proposedTime,
        uint256 executeTime,
        uint256 expiryTime,
        uint256 approvalCount,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposalType,
            proposal.proposer,
            proposal.newValue,
            proposal.proposedTime,
            proposal.executeTime,
            proposal.expiryTime,
            proposal.approvalCount,
            proposal.executed
        );
    }

    /**
     * @dev Checks if a signer has approved a specific proposal.
     */
    function hasApproved(uint256 proposalId, address signer) external view returns (bool approved) {
        return proposalApprovals[proposalId][signer];
    }

    /**
     * @dev Returns the list of signers who have approved a specific proposal.
     */
    function getProposalApprovals(uint256 proposalId) external view returns (address[] memory approvedSigners) {
        uint256 count = 0;
        uint256 len = signers.length;
        for (uint256 i = 0; i < len; ++i) {
            if (proposalApprovals[proposalId][signers[i]]) {
                count++;
            }
        }

        approvedSigners = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < len; ++i) {
            if (proposalApprovals[proposalId][signers[i]]) {
                approvedSigners[index] = signers[i];
                index++;
            }
        }
    }

    // ----------------- Complete Administrative Functions -----------------
    
    /**
     * @dev Allows the owner to exclude multiple accounts from fees.
     */
    function excludeFromFeeMultiple(address[] calldata accounts, bool status) external onlyOwner {
        uint256 len = accounts.length;
        for(uint256 i = 0; i < len; ++i) {
            isExcludedFromFee[accounts[i]] = status;
            emit FeeExemptionStatusUpdated(accounts[i], status);
        }
    }

    /**
     * @dev Allows the owner to set multiple market pairs.
     */
    function setMarketPairs(address[] calldata accounts, bool status) external onlyOwner {
        uint256 len = accounts.length;
        for(uint256 i = 0; i < len; ++i) {
            isMarketPair[accounts[i]] = status;
            emit MarketPairStatusUpdated(accounts[i], status);
        }
    }

    // ----------------- Security Best Practices -----------------
    
    /**
     * @dev Conducts a periodic security review (placeholder function).
     * This should be implemented with actual audit logic or tools.
     */
    function conductSecurityReview() external onlyOwner {
        // Placeholder for security review logic
        // In practice, this could trigger an off-chain audit or other security mechanisms
    }
}
