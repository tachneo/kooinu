
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Koo Inu (KOO) Smart Contract
 * @dev ERC20 Token with Fee Management, Automated Liquidity Provision, and Enhanced Security Features
 * Coded by info@tachy.in
 * @custom:dev-run-script ./scripts/deploy.js
 */

/**
 * @dev Provides information about the current execution context.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
contract Ownable is Context {
    address internal _owner;
    address internal _previousOwner;
    uint256 internal _lockTime;

    // Event emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        _previousOwner = address(0);
        _lockTime = 0;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Modifier to restrict function access to the owner only.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * Ownership is waived permanently, and cannot be reclaimed.
     */
    function waiveOwnership() public virtual onlyOwner {
        require(_owner != address(0), "Ownable: ownership already waived");
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
        _previousOwner = address(0);
        _lockTime = 0;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     * @dev Locks the contract for the owner for the specified amount of time.
     * Can only be called by the current owner. This function cannot be used if ownership has been waived.
     */
    function lock(uint256 time) public virtual onlyOwner {
        require(_owner != address(0), "Ownable: ownership has been waived, cannot lock");
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_previousOwner, address(0));
    }

    /**
     * @dev Unlocks the contract for the owner after the lock time has passed.
     * Can only be called by the previous owner or the second owner.
     */
    function unlock() public virtual {
        require(_previousOwner == _msgSender() || _previousOwner == _msgSender(), "Ownable: caller is not authorized to unlock");
        require(block.timestamp > _lockTime, "Ownable: still locked");
        require(_previousOwner != address(0), "Ownable: ownership permanently waived");
        emit OwnershipTransferred(address(0), _previousOwner);
        _owner = _previousOwner;
        _previousOwner = address(0);
        _lockTime = 0;
    }
}

/**
 * @dev Contract module to prevent reentrant calls to a function.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 internal _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Modifier to prevent reentrant calls.
     */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;

        _;

        _status = _NOT_ENTERED;
    }
}

/**
 * @dev Interface defining the ERC20 standard functions and events.
 */
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

/**
 * @dev Library with utility functions related to the address type.
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     */
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // Perform the call and check for success
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: ETH transfer failed");
    }
}

/**
 * @dev Interface for the Uniswap V2 Factory.
 */
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

/**
 * @dev Interface for the Uniswap V2 Router01.
 */
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    // Liquidity management functions
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    // Swap functions
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint[] memory amounts);

    // Utility functions
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

/**
 * @dev Interface for the Uniswap V2 Router02, extending Router01 with additional functions.
 */
interface IUniswapV2Router02 is IUniswapV2Router01 {
    // Removes liquidity with support for fee on transfer tokens
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH);

    // Swaps with support for fee on transfer tokens
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
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

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/**
 * @dev Main contract implementing the ERC20 token with additional features.
 */
contract KooInu is Context, IERC20, Ownable, ReentrancyGuard {

    using Address for address payable;  // Using Address library for address type

    // Token details
    string private _name = "Koo Inu";
    string private _symbol = "KOO";
    uint8 private _decimals = 9;

    // Wallet addresses for marketing and team funds
    address payable public marketingWalletAddress;
    address payable public teamWalletAddress;
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD; // Dead address for burning tokens

    // Mapping to keep track of each account's balance
    mapping (address => uint256) private _balances;
    // Mapping to keep track of allowances
    mapping (address => mapping (address => uint256)) private _allowances;

    // Mappings to manage fee and limit exemptions
    mapping (address => bool) public isExcludedFromFee;
    mapping (address => bool) public isWalletLimitExempt;
    mapping (address => bool) public isTxLimitExempt;
    mapping (address => bool) public isMarketPair;

    // Fees for buying (in basis points: 1 BP = 0.01%)
    uint256 public _buyLiquidityFeeBP = 100; // 1%
    uint256 public _buyMarketingFeeBP = 100; // 1%
    uint256 public _buyTeamFeeBP = 100; // 1%

    // Fees for selling (in basis points)
    uint256 public _sellLiquidityFeeBP = 100; // 1%
    uint256 public _sellMarketingFeeBP = 100; // 1%
    uint256 public _sellTeamFeeBP = 100; // 1%

    // Distribution shares (in basis points)
    uint256 public _liquidityShareBP = 400; // 4%
    uint256 public _marketingShareBP = 400; // 4%
    uint256 public _teamShareBP = 1600; // 16%

    // Total taxes (in basis points)
    uint256 public _totalTaxIfBuyingBP = 300; // 3%
    uint256 public _totalTaxIfSellingBP = 300; // 3%
    uint256 public _totalDistributionSharesBP = 2400; // 24%

    // Total supply and limits
    uint256 private _totalSupply = 1e24; // Total Supply: 1,000,000,000,000,000,000,000,000 KOO
    uint256 public _maxTxAmount = _totalSupply;
    uint256 public _walletMax = _totalSupply;
    uint256 private minimumTokensBeforeSwap = _totalSupply / 100; // 1% of total supply

    // Maximum fee limits
    uint256 private constant MAX_TOTAL_FEE_BP = 500; // Maximum total fee is 5%
    uint256 private constant MAX_INDIVIDUAL_FEE_BP = 300; // Maximum individual fee is 3%

    // Uniswap router and pair addresses
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    // Flags for swap and liquify functionality
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public swapAndLiquifyByLimitOnly = false;
    bool public checkWalletLimit = true;

    // Events
    event ExcludedFromFee(address indexed account, bool isExcluded);
    event WalletLimitExempt(address indexed account, bool isExempt);
    event TxLimitExempt(address indexed account, bool isExempt);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );
    event EtherTransferred(address indexed recipient, uint256 amount);
    event EtherWithdrawn(address indexed owner, uint256 amount);
    event ERC20Withdrawn(address indexed owner, address indexed token, uint256 amount);
    event MarketPairStatusUpdated(address indexed account, bool newValue);
    event TxLimitExemptStatusUpdated(address indexed holder, bool exempt);
    event FeeExemptionStatusUpdated(address indexed account, bool newValue);
    event BuyUpdated(uint256 lFeeBP, uint256 mFeeBP, uint256 tFeeBP);
    event SellTaxesUpdated(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP);
    event DistributionSettingsUpdated(uint256 liquidityShareBP, uint256 marketingShareBP, uint256 teamShareBP);
    event TotalDistributionSharesUpdated(uint256 totalDistributionSharesBP);
    event MaxTxAmountUpdated(uint256 maxTxAmount);
    event WalletLimitUpdated(uint256 newLimit);
    event NumTokensBeforeSwapUpdated(uint256 newLimit);
    event SwapAndLiquifyByLimitOnlyUpdated(bool newValue);
    event SecondOwnerSet(address indexed secondOwner);

    // Modifier to prevent reentrancy during swap and liquify
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    // Modifier to enforce tax change cooldown
    modifier canChangeTaxes() {
        require(block.timestamp >= lastTaxChangeTimestamp + TAX_CHANGE_COOLDOWN, "Cannot change taxes yet.");
        _;
    }

    // Ownership multi-sig variables
    address private _secondOwner;

    // Cooldown settings
    uint256 public lastTaxChangeTimestamp;
    uint256 public constant TAX_CHANGE_COOLDOWN = 1 days; // Cooldown period of 1 day

    /**
     * @dev Constructor to initialize the contract
     */
    constructor () ReentrancyGuard() {
        // Set the marketing and team wallet addresses
        marketingWalletAddress = payable(0x3589D4cdB885137DBCA8662A5BD4F39079db8365); // Marketing Address
        teamWalletAddress = payable(0xE42Fe8079677Cd17E5f4C5b7E6d90bfC55EA7741); // Team Address

        // Assign the total supply to the owner
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);

        // Initialize Uniswap Router
        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Replace with actual router address

        // Create a Uniswap pair for this token
        uniswapPair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());

        // Exclude owner, contract, and Uniswap pair from fee
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[uniswapPair] = true;

        // Set wallet limit exemptions
        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;
        isWalletLimitExempt[uniswapPair] = true; // Correctly exclude the actual pair from limits

        // Set the Uniswap pair as a market pair
        isMarketPair[uniswapPair] = true;
    }

    /**
     * @dev Function to set a second owner (for multi-signature)
     */
    function setSecondOwner(address secondOwner) external onlyOwner {
        require(secondOwner != address(0), "Second owner cannot be zero address");
        _secondOwner = secondOwner;
        emit SecondOwnerSet(secondOwner);
    }

    // ----------------- ERC20 Standard Functions -----------------

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the total supply of the token.
     */
    function totalSupply() public view override returns (uint256) {
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
     * @dev Increases the allowance of a spender.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        require(spender != address(0), "KooInu: increase allowance to the zero address");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Decreases the allowance of a spender.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        require(spender != address(0), "KooInu: decrease allowance to the zero address");
        require(_allowances[_msgSender()][spender] >= subtractedValue, "KooInu: decreased allowance below zero");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    /**
     * @dev Returns the minimum number of tokens required before a swap can occur.
     */
    function minimumTokensBeforeSwapAmount() public view returns (uint256) {
        return minimumTokensBeforeSwap;
    }

    /**
     * @dev Approves a spender to spend a specified amount of tokens on behalf of the caller.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), "KooInu: approve to the zero address");
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Internal function to handle approvals.
     */
    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0) && spender != address(0), "KooInu: approve from/to the zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    // ----------------- Administrative Functions -----------------

    /**
     * @dev Function to set market pair status
     */
    function setMarketPairStatus(address account, bool newValue) external onlyOwner {
        isMarketPair[account] = newValue;
        emit MarketPairStatusUpdated(account, newValue);
    }

    /**
     * @dev Function to set transaction limit exemption
     */
    function setIsTxLimitExempt(address account, bool exempt) external onlyOwner {
        isTxLimitExempt[account] = exempt;
        emit TxLimitExemptStatusUpdated(account, exempt);
    }

    /**
     * @dev Function to set fee exemption status
     */
    function setIsExcludedFromFee(address account, bool newValue) external onlyOwner {
        isExcludedFromFee[account] = newValue;
        emit FeeExemptionStatusUpdated(account, newValue);
    }

    /**
     * @dev Function to set wallet limit exemption
     */
    event WalletLimitExemptStatusUpdated(address indexed account, bool exempt);

    function setIsWalletLimitExempt(address account, bool exempt) external onlyOwner {
        isWalletLimitExempt[account] = exempt;
        emit WalletLimitExemptStatusUpdated(account, exempt);
    }

    /**
     * @dev Function to set distribution shares with enforced limits
     */
    function setFees(
        uint256 buyLiquidityFeeBP,
        uint256 buyMarketingFeeBP,
        uint256 buyTeamFeeBP,
        uint256 sellLiquidityFeeBP,
        uint256 sellMarketingFeeBP,
        uint256 sellTeamFeeBP
    ) external onlyOwner {
        require(
            buyLiquidityFeeBP + buyMarketingFeeBP + buyTeamFeeBP <= MAX_TOTAL_FEE_BP &&
            sellLiquidityFeeBP + sellMarketingFeeBP + sellTeamFeeBP <= MAX_TOTAL_FEE_BP,
            "Total fee exceeds limit"
        );

        require(
            buyLiquidityFeeBP <= MAX_INDIVIDUAL_FEE_BP && 
            buyMarketingFeeBP <= MAX_INDIVIDUAL_FEE_BP &&
            buyTeamFeeBP <= MAX_INDIVIDUAL_FEE_BP &&
            sellLiquidityFeeBP <= MAX_INDIVIDUAL_FEE_BP &&
            sellMarketingFeeBP <= MAX_INDIVIDUAL_FEE_BP &&
            sellTeamFeeBP <= MAX_INDIVIDUAL_FEE_BP,
            "Individual fee exceeds limit"
        );

        _buyLiquidityFeeBP = buyLiquidityFeeBP;
        _buyMarketingFeeBP = buyMarketingFeeBP;
        _buyTeamFeeBP = buyTeamFeeBP;
        _sellLiquidityFeeBP = sellLiquidityFeeBP;
        _sellMarketingFeeBP = sellMarketingFeeBP;
        _sellTeamFeeBP = sellTeamFeeBP;

        _totalTaxIfBuyingBP = buyLiquidityFeeBP + buyMarketingFeeBP + buyTeamFeeBP;
        _totalTaxIfSellingBP = sellLiquidityFeeBP + sellMarketingFeeBP + sellTeamFeeBP;

        emit BuyUpdated(buyLiquidityFeeBP, buyMarketingFeeBP, buyTeamFeeBP);
        emit SellTaxesUpdated(sellLiquidityFeeBP, sellMarketingFeeBP, sellTeamFeeBP);
    }

    function setDistributionShares(
        uint256 liquidityShareBP,
        uint256 marketingShareBP,
        uint256 teamShareBP
    ) external onlyOwner {
        require(
            liquidityShareBP + marketingShareBP + teamShareBP <= MAX_TOTAL_FEE_BP,
            "Total shares exceed limit"
        );

        _liquidityShareBP = liquidityShareBP;
        _marketingShareBP = marketingShareBP;
        _teamShareBP = teamShareBP;
        _totalDistributionSharesBP = liquidityShareBP + marketingShareBP + teamShareBP;

        emit DistributionSettingsUpdated(liquidityShareBP, marketingShareBP, teamShareBP);
        emit TotalDistributionSharesUpdated(_totalDistributionSharesBP);
    }


    /**
     * @dev Function to enable/disable swap and liquify
     */
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /**
     * @dev Function to set swap and liquify condition
     */
    function setSwapAndLiquifyByLimitOnly(bool newValue) external onlyOwner {
        swapAndLiquifyByLimitOnly = newValue;
        emit SwapAndLiquifyByLimitOnlyUpdated(newValue);
    }

    /**
     * @dev Function to set wallet limit
     */
    function setWalletLimit(uint256 newLimit) external onlyOwner {
        require(newLimit >= _totalSupply / 1000, "Wallet limit too low"); // Minimum 0.1% of total supply
        _walletMax = newLimit;
        emit WalletLimitUpdated(newLimit);
    }

    /**
     * @dev Function to set maximum transaction amount
     */
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        require(maxTxAmount >= _totalSupply / 1000, "Max TX amount too low"); // Minimum 0.1% of total supply
        _maxTxAmount = maxTxAmount;
        emit MaxTxAmountUpdated(maxTxAmount);
    }

    /**
     * @dev Function to set minimum tokens before swap
     */
    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
        emit NumTokensBeforeSwapUpdated(newLimit);
    }

    // ----------------- Withdrawal Functions -----------------

    /**
     * @dev Transfers Ether to a specified address.
     * @param recipient The address to receive Ether.
     * @param amount The amount of Ether to transfer in wei.
     */
    function transferToAddressETH(address payable recipient, uint256 amount) private {
        require(address(this).balance >= amount, "KooInu: Low balance");

        // Attempt to transfer Ether
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "KooInu: ETH transfer failed.");

        // Emit event to log the successful ETH transfer
        emit EtherTransferred(recipient, amount);
    }

    /**
     * @dev Withdraws Ether from the contract to the owner's address.
     * @param amount The amount of Ether to withdraw in wei.
     */
    function withdrawEther(uint256 amount) external onlyOwner nonReentrant {
        require(address(this).balance >= amount, "KooInu: low balance");
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "KooInu: ETH transfer failed.");
        emit EtherWithdrawn(owner(), amount);
    }

    /**
     * @dev Withdraws ERC20 tokens from the contract to the owner's address.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     * @param tokenAmount The amount of tokens to withdraw.
     */
    function withdrawERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner nonReentrant {
        require(tokenAddress != address(this), "KooInu: Cannot withdraw own tokens");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit ERC20Withdrawn(owner(), tokenAddress, tokenAmount);
    }

    /**
     * @dev Transfers tokens to a specified address.
     * @param recipient The address to receive tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another using allowance.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        require(_allowances[sender][_msgSender()] >= amount, "KooInu: allowance exceeded");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    // ----------------- Internal Transfer Function -----------------

    /**
     * @dev Internal function to handle transfers, including fee logic and swap & liquify.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(address sender, address recipient, uint256 amount) private nonReentrant {
        require(sender != address(0), "KooInu: transfer from zero address");
        require(recipient != address(0), "KooInu: transfer to zero address");
        require(amount > 0, "KooInu: amount must be greater than zero");
        require(_balances[sender] >= amount, "KooInu: insufficient balance");

        if (inSwapAndLiquify) {
            _basicTransfer(sender, recipient, amount);
            return;
        }

        _balances[sender] -= amount;

        uint256 feeAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ? 0 : _calculateFee(sender, recipient, amount);
        uint256 transferAmount = amount - feeAmount;

        _balances[recipient] += transferAmount;
        if (feeAmount > 0) _balances[address(this)] += feeAmount;

        emit Transfer(sender, recipient, transferAmount);
        if (feeAmount > 0) emit Transfer(sender, address(this), feeAmount);

        if (!_inSwapCheck(sender)) _handleSwap();
    }

    function _calculateFee(address sender, address recipient, uint256 amount) private view returns (uint256) {
        return isMarketPair[sender] ? (amount * _totalTaxIfBuyingBP) / 10000
            : isMarketPair[recipient] ? (amount * _totalTaxIfSellingBP) / 10000
            : 0;
    }

    function _inSwapCheck(address sender) private view returns (bool) {
        return inSwapAndLiquify || isMarketPair[sender] || !swapAndLiquifyEnabled || _balances[address(this)] < minimumTokensBeforeSwap;
    }

    function _handleSwap() private lockTheSwap {
        uint256 tokensToSwap = swapAndLiquifyByLimitOnly ? minimumTokensBeforeSwap : _balances[address(this)];
        swapAndLiquify(tokensToSwap);
    }


    /**
     * @dev Performs a basic transfer without taking any fees.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] -= amount; // Subtract from sender
        _balances[recipient] += amount; // Add to recipient
        emit Transfer(sender, recipient, amount); // Emit transfer event
        return true;
    }

    /**
     * @dev Handles swapping tokens for ETH and adding liquidity.
     * @param tAmount The amount of tokens to swap and liquify.
     */
    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        // Split tokens for liquidity provision and swap
        uint256 tokensForLP = (tAmount * _liquidityShareBP) / (_totalDistributionSharesBP * 2);  // Half liquidity
        uint256 tokensForSwap = tAmount - tokensForLP;  // Rest is for swap

        if (tokensForSwap > 0) {
            // Swap tokens for WBNB (on PancakeSwap WBNB is used)
            swapTokensForWBNB(tokensForSwap);
            uint256 amountReceived = address(this).balance;

            if (amountReceived > 0) {
                uint256 totalBNBFee = _totalDistributionSharesBP - (_liquidityShareBP / 2);

                uint256 amountBNBLiquidity = (amountReceived * _liquidityShareBP) / totalBNBFee / 2;
                uint256 amountBNBTeam = (amountReceived * _teamShareBP) / totalBNBFee;
                uint256 amountBNBMarketing = amountReceived - amountBNBLiquidity - amountBNBTeam;

                if (amountBNBMarketing > 0)
                    transferToAddressETH(marketingWalletAddress, amountBNBMarketing);  // Transfer to marketing wallet

                if (amountBNBTeam > 0)
                    transferToAddressETH(teamWalletAddress, amountBNBTeam);  // Transfer to team wallet

                if (amountBNBLiquidity > 0 && tokensForLP > 0) {
                    addLiquidity(tokensForLP, amountBNBLiquidity);  // Automatically add liquidity using WBNB
                }
            }
        }
    }

    /**
     * @dev Swaps a specified amount of tokens for WBNB using PancakeSwap.
     * @param tokenAmount The amount of tokens to swap.
     */
    function swapTokensForWBNB(uint256 tokenAmount) private {
        require(tokenAmount > 0, "KooInu: Tokens amount must be greater than zero");

        address[] memory path = new address[](2); // Correctly declare the path as an array of addresses
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH(); // WETH() returns WBNB on BSC

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount of WBNB
            path,
            address(this),
            block.timestamp
        );

        emit SwapTokensForETH(tokenAmount, path);
    }

    /**
     * @dev Adds liquidity to PancakeSwap using the specified token and WBNB amounts.
     * @param tokenAmount The amount of tokens to add to liquidity.
     * @param bnbAmount The amount of WBNB to add to liquidity.
     */
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private nonReentrant {
        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve token transfer to the router

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // Slippage is unavoidable
            0, // Slippage is unavoidable
            owner(),
            block.timestamp
        );

        emit SwapAndLiquify(tokenAmount, bnbAmount, tokenAmount);
    }

    /**
     * @dev Takes fee on transactions based on whether it's a buy or sell.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     * @return The amount after deducting fees.
     */
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;

        bool isBuy = isMarketPair[sender];
        bool isSell = isMarketPair[recipient];

        if(isBuy || isSell) {
            uint256 totalTaxBP = isBuy ? _totalTaxIfBuyingBP : _totalTaxIfSellingBP;
            feeAmount = (amount * totalTaxBP) / 10000;
        }

        if(feeAmount > 0) {
            _balances[address(this)] += feeAmount;
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount - feeAmount;
    }

    // ----------------- Additional Functions -----------------

    /**
     * @dev Function to get circulating supply.
     */
    function getCirculatingSupply() external view returns (uint256) {
        return _totalSupply - balanceOf(deadAddress);
    }

    /**
     * @dev Enhanced unlock function requiring confirmation from second owner
     */
    function unlock() public virtual override {
        require(_previousOwner == _msgSender() || _secondOwner == _msgSender(), "Ownable: caller is not authorized to unlock");
        require(block.timestamp > _lockTime, "Ownable: still locked");
        require(_previousOwner != address(0), "Ownable: ownership permanently waived");
        emit OwnershipTransferred(address(0), _previousOwner);
        _owner = _previousOwner;
        _previousOwner = address(0);
        _lockTime = 0;
    }


    /**
     * @dev Fallback function to receive ETH from UniswapV2Router when swapping
     */
    receive() external payable {}
}
