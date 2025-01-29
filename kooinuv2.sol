// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Koo Inu (KOO) Smart Contract
 * @dev ERC20 Token with Fee Management, Automated Liquidity Provision, and Enhanced Security Features
 * coded by info@tachy.in
 * @custom:dev-run-script ./scripts/deploy.js
 */

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // Silence state mutability warning without generating bytecode
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;
    bool private _ownershipWaived; // New state variable to track ownership waiver

    // Event emitted when ownership is transferred
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
     * @dev Modifier to restrict function access to the owner only.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Own");
        _;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * Ownership is waived permanently, and cannot be reclaimed.
     */
    function waiveOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _previousOwner = address(0); // Ensure previous owner is also set to address 0
        _owner = address(0);
        _ownershipWaived = true; // Mark ownership as waived
    }



    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Zero");
        require(!_ownershipWaived, "Ownership has been waived permanently"); // Prevent transfer after waiving ownership
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     * @dev Returns the unlock time if the contract is locked.
     */
    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    /**
     * @dev Returns the current block timestamp.
     */
    function getTime() public view returns (uint256) {
        return block.timestamp;
    }

    /**
     * @dev Locks the contract for the owner for the specified amount of time.
     * Can only be called by the current owner. This function cannot be used if ownership has been waived.
     */
    function lock(uint256 time) public virtual onlyOwner {
        require(!_ownershipWaived, "Ownership has been waived, cannot lock"); // Prevent locking if ownership is waived
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }

    /**
     * @dev Unlocks the contract for the owner after the lock time has passed.
     * Can only be called by the previous owner. This function cannot be used if ownership has been waived.
     */
    function unlock() public virtual {
        require(_previousOwner == _msgSender(), "Prev own");
        require(block.timestamp > _lockTime, "Still locked");
        require(_previousOwner != address(0), "Ownership permanently waived"); // Ensure no previous owner
        emit OwnershipTransferred(address(0), _previousOwner);
        _owner = _previousOwner;
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
     *
     * IMPORTANT:
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * IMPORTANT:
     * Because control is transferred to `recipient`, care must be taken
     * to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the checks-effects-interactions pattern.
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance > amount, "Address: insufficient balance");

        // Perform the call and check for success
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: ETH transfer failed");
    }
}

/**
 * @dev Reentrancy guard contract to prevent reentrant calls.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Applying the nonReentrant modifier to functions ensures that there are no nested (reentrant) calls to them.
     */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;

        _;

        _status = _NOT_ENTERED;
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
 * @dev Interface for the Uniswap V2 Pair.
 */
interface IUniswapV2Pair {
    // ERC20 metadata functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // ERC20 supply and balance functions
    function totalSupply() external view returns (uint);
    function balanceOf(address owner_) external view returns (uint);
    function allowance(address owner_, address spender) external view returns (uint);

    // ERC20 approval and transfer functions
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from,address to,uint value) external returns (bool);

    // EIP-2612 permit functionality
    function permit(
        address owner_,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    // Liquidity functions
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
    function skim(address to) external;
    function sync() external;

    // Initializes the pair
    function initialize(address, address) external;
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
    uint256 private _totalSupply = 1e24; // Total Supply: (1e24)
    uint256 public _maxTxAmount = _totalSupply;
    uint256 public _walletMax = _totalSupply;
    uint256 private minimumTokensBeforeSwap = _totalSupply / 100; // 1% of total supply

    // Maximum fee limits
    uint256 private constant MAX_TOTAL_FEE_BP = 500; // Maximum total fee is 5%
    uint256 private constant MAX_INDIVIDUAL_FEE_BP = 300; // Maximum individual fee is 3%

    // Minimum and maximum transaction and wallet limits (updated naming for consistency)
    uint256 public minTxAmount = 0; // Minimum 0.0% of total supply
    uint256 public maxTxAmount = _totalSupply; // Max is total supply
    uint256 public minWalletLimit = 0; // Minimum 0.01% of total supply
    uint256 public maxWalletLimit = _totalSupply; // Max is total supply

    // Uniswap router and pair addresses
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    // Flags for swap and liquify functionality
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;
    bool public swapAndLiquifyByLimitOnly;
    bool public checkWalletLimit;

    event ExcludedFromFee(address indexed account, bool isExcluded);
    event WalletLimitExempt(address indexed account, bool isExempt);
    event TxLimitExempt(address indexed account, bool isExempt);

    // Events related to swap and liquify
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    // Events for token and ETH swaps
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );

    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );

    // Modifier to prevent reentrancy during swap and liquify
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    // Constructor to initialize the contract
    // Constructor to initialize the contract
// Constructor to initialize the contract
    constructor () ReentrancyGuard() {
        marketingWalletAddress = payable(0x3589D4cdB885137DBCA8662A5BD4F39079db8365);
        teamWalletAddress = payable(0xE42Fe8079677Cd17E5f4C5b7E6d90bfC55EA7741);
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);

        // Initialize Uniswap V2 Router and Pair
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;

        isMarketPair[uniswapPair] = true;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;
        isWalletLimitExempt[uniswapPair] = true; // Correctly exempt the pair address
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
        require(spender != address(0), "KooInu: increase allowance");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Decreases the allowance of a spender.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        require(spender != address(0), "KooInu: decrease allowance");
        require(_allowances[_msgSender()][spender] > subtractedValue, "KooInu: decreased allowance");
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
        require(spender != address(0), "approve");
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Internal function to handle approvals.
     */
    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0) && spender != address(0), "invalid");


        _allowances[owner_][spender] = amount; // Set the allowance
        emit Approval(owner_, spender, amount); // Emit Approval event
    }


    // ----------------- Administrative Functions -----------------

    // Function to set market pair status
    function setMarketPairStatus(address account, bool newValue) external onlyOwner {
        isMarketPair[account] = newValue;
        emit MarketPairStatusUpdated(account, newValue);
    }

    // Function to set transaction limit exemption
    function setIsTxLimitExempt(address account, bool exempt) external onlyOwner {
        isTxLimitExempt[account] = exempt;
        emit TxLimitExempt(account, exempt); // New event for transparency
    }


    function setIsExcludedFromFee(address account, bool newValue) external onlyOwner {
        isExcludedFromFee[account] = newValue;
        emit ExcludedFromFee(account, newValue); // New event for transparency
    }

    function setIsWalletLimitExempt(address account, bool exempt) external onlyOwner {
        isWalletLimitExempt[account] = exempt;
        emit WalletLimitExempt(account, exempt); // New event for transparency
    }

    uint256 public lastTaxChangeTimestamp;
    uint256 public constant TAX_CHANGE_COOLDOWN = 1 days; // Cooldown period of 1 day

    modifier canChangeTaxes() {
        require(block.timestamp >= lastTaxChangeTimestamp + TAX_CHANGE_COOLDOWN, "Cannot change taxes yet.");
        _;
    }

    function setBuyFees(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP) external onlyOwner canChangeTaxes {
        require(liquidityFeeBP + marketingFeeBP + teamFeeBP <= MAX_TOTAL_FEE_BP, "Buy fees exceed maximum");
        _buyLiquidityFeeBP = liquidityFeeBP;
        _buyMarketingFeeBP = marketingFeeBP;
        _buyTeamFeeBP = teamFeeBP;
        _totalTaxIfBuyingBP = liquidityFeeBP + marketingFeeBP + teamFeeBP;
        lastTaxChangeTimestamp = block.timestamp;
        emit BuyFeesUpdated(liquidityFeeBP, marketingFeeBP, teamFeeBP);
    }

    function setSellFees(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP) external onlyOwner canChangeTaxes {
        require(liquidityFeeBP + marketingFeeBP + teamFeeBP <= MAX_TOTAL_FEE_BP, "Sell fees exceed maximum");
        _sellLiquidityFeeBP = liquidityFeeBP;
        _sellMarketingFeeBP = marketingFeeBP;
        _sellTeamFeeBP = teamFeeBP;
        _totalTaxIfSellingBP = liquidityFeeBP + marketingFeeBP + teamFeeBP;
        lastTaxChangeTimestamp = block.timestamp;
        emit SellFeesUpdated(liquidityFeeBP, marketingFeeBP, teamFeeBP);
    }


    // Function to set distribution shares
    function setDistributionSettings(uint256 newLiquidityShareBP, uint256 newMarketingShareBP, uint256 newTeamShareBP) external onlyOwner {
        require(newLiquidityShareBP + newMarketingShareBP + newTeamShareBP <= 10000, "Total shares exceed 100%");
        require(newLiquidityShareBP <= 10000 && newMarketingShareBP <= 10000 && newTeamShareBP <= 10000, "Individual share too high");
        _liquidityShareBP = newLiquidityShareBP;
        _marketingShareBP = newMarketingShareBP;
        _teamShareBP = newTeamShareBP;
        _totalDistributionSharesBP = newLiquidityShareBP + newMarketingShareBP + newTeamShareBP;
        emit DistributionSettingsUpdated(newLiquidityShareBP, newMarketingShareBP, newTeamShareBP);
    }


    // Function to enable/disable swap and liquify
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    // Function to set swap and liquify condition
    function setSwapAndLiquifyByLimitOnly(bool newValue) external onlyOwner {
        swapAndLiquifyByLimitOnly = newValue;
        emit SwapAndLiquifyByLimitOnlyUpdated(newValue);
    }

    // Function to get circulating supply
    function getCirculatingSupply() external view returns (uint256) {
        return _totalSupply - balanceOf(deadAddress);
    }

    // ----------------- Withdrawal Functions -----------------

    /**
     * @dev Transfers Ether to a specified address.
     * @param recipient The address to receive Ether.
     * @param amount The amount of Ether to transfer in wei.
     */
    // Add event for Ether transfer
    event EtherTransferred(address indexed recipient, uint256 amount);

    function transferToAddressETH(address payable recipient, uint256 amount) private {
        require(address(this).balance >= amount, "KooInu: Low balance");

        // Attempt to transfer Ether
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "KooInu: ETH transfer failed.");

        // Emit event to log the successful ETH transfer
        emit EtherTransferred(recipient, amount);
    }


     // Function to receive ETH from UniswapV2Router when swapping
    receive() external payable {}

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        require(_allowances[sender][_msgSender()] >= amount, "Allowance exceeded");
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
    function _transfer(address sender, address recipient, uint256 amount) private nonReentrant returns (bool) {
        require(sender != address(0), "KooInu: transfer from the zero address");
        require(recipient != address(0), "KooInu: transfer to the zero address");
        require(amount > 0, "Amt > 0");

        if (inSwapAndLiquify) {
            return _basicTransfer(sender, recipient, amount);
        } else {
            require(_balances[sender] >= amount, "KooInu: Insufficient balance for transfer");
            
            // Subtract balance from sender first
            _balances[sender] = _balances[sender] - amount;

            // Calculate final amount after fees
            uint256 finalAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) 
                ? amount 
                : takeFee(sender, recipient, amount);

            // Check wallet limit BEFORE updating recipient's balance
            if (!isWalletLimitExempt[recipient]) {
                require(
                    _balances[recipient] + finalAmount <= maxWalletLimit,
                    "Exceeds max wallet limit"
                );
            }

            // Update recipient's balance
            _balances[recipient] += finalAmount;
            emit Transfer(sender, recipient, finalAmount);

            // Rest of the logic (swapAndLiquify checks)
            uint256 contractTokenBalance = balanceOf(address(this));
            bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;

            if (overMinimumTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) {
                if (swapAndLiquifyByLimitOnly) {
                    contractTokenBalance = minimumTokensBeforeSwap;
                }
                swapAndLiquify(contractTokenBalance);
            }

            return true;
        }
    }



    /**
     * @dev Performs a basic transfer without taking any fees.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender] - amount; // Subtract from sender
        _balances[recipient] = _balances[recipient] + amount; // Add to recipient
        emit Transfer(sender, recipient, amount); // Emit transfer event
        return true;
    }

    /**
     * @dev Handles swapping tokens for ETH and adding liquidity.
     * @param tAmount The amount of tokens to swap and liquify.
     */

    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        // Split tokens for liquidity provision and swap
        uint256 tokensForLP = (tAmount * _liquidityShareBP) / _totalDistributionSharesBP / 2; // Correct split  // Half liquidity
        uint256 tokensForSwap = tAmount - tokensForLP;  // Rest is for swap

        if (tokensForSwap > 0) {
            // Swap tokens for WBNB (on PancakeSwap WBNB is used)
            swapTokensForWBNB(tokensForSwap);
            uint256 amountReceived = address(this).balance;

            if (amountReceived > 0) {
                uint256 totalBNBFee = _totalDistributionSharesBP;
                // Proceed with distribution based on shares without subtraction

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
        require(tokenAmount > 0, "Tokens > 0");

        address[] memory path = new address[](2);
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
    }

    /**
    * @dev Adds liquidity to PancakeSwap using the specified token and WBNB amounts.
    * @param tokenAmount The amount of tokens to add to liquidity.
    * @param bnbAmount The amount of WBNB to add to liquidity.
    */
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private nonReentrant {
        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve token transfer to the router

        // Add the liquidity
        address liquidityReceiver = owner() != address(0) ? owner() : deadAddress;
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidityReceiver,
            block.timestamp
        );
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
            feeAmount = (amount * totalTaxBP) / 10000; // Direct calculation

        }


        if(feeAmount > 0) {
            _balances[address(this)] += feeAmount; // Add fee to contract balance
            emit Transfer(sender, address(this), feeAmount); // Emit transfer event for fee
        }

        return amount - feeAmount; // Return the amount after fee deduction
    }

    // ----------------- Withdrawal Functions -----------------

    /**
     * @dev Withdraws Ether from the contract to the owner's address.
     * @param amount The amount of Ether to withdraw in wei.
     */
    // Add event for Ether withdrawal
    event EtherWithdrawn(address indexed owner, uint256 amount);

    function withdrawEther(uint256 amount) external onlyOwner nonReentrant {
        require(address(this).balance > amount, "KooInu: low balance");
        // Line 1074 (Ether Withdraw Function)
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "KooInu: ETH transfer failed.");
        emit EtherWithdrawn(owner(), amount);
    }



    // Add event for ERC20 withdrawal
    event ERC20Withdrawn(address indexed owner, address indexed token, uint256 amount);

    function withdrawERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner nonReentrant {
        require(tokenAddress != address(this), "KooInu: Cannot withdraw");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit ERC20Withdrawn(owner(), tokenAddress, tokenAmount);
    }

    // ----------------- Event Declarations for Enhanced Access Control Transparency -----------------

    /**
     * @dev Emitted when the market pair status of an account is updated.
     */
    event MarketPairStatusUpdated(address indexed account, bool newValue);

    /**
     * @dev Emitted when the transaction limit exemption status of a holder is updated.
     */
    event TxLimitExemptStatusUpdated(address indexed holder, bool exempt);

    /**
     * @dev Emitted when the fee exemption status of an account is updated.
     */
    event FeeExemptionStatusUpdated(address indexed account, bool newValue);

    /**
     * @dev Emitted when the buy taxes are updated.
     */
    event BuyFeesUpdated(uint256 lFeeBP, uint256 mFeeBP, uint256 tFeeBP);


    /**
     * @dev Emitted when the sell taxes are updated.
     */
    event SellFeesUpdated(uint256 liquidityFeeBP, uint256 marketingFeeBP, uint256 teamFeeBP);

    /**
     * @dev Emitted when the distribution shares are updated.
     */
    event DistributionSettingsUpdated(uint256 liquidityShareBP, uint256 marketingShareBP, uint256 teamShareBP);

    /**
     * @dev Emitted when the maximum transaction amount is updated.
     */
    event MaxTxAmountUpdated(uint256 maxTxAmount);

    /**
     * @dev Emitted when the wallet limit is enabled or disabled.
     */
    event WalletLimitEnabled(bool enabled);

    /**
     * @dev Emitted when the wallet limit exemption status of a holder is updated.
     */
    event WalletLimitExemptStatusUpdated(address indexed holder, bool exempt);

    /**
     * @dev Emitted when the wallet limit is updated.
     */
    event WalletLimitUpdated(uint256 newLimit);

    /**
     * @dev Emitted when the number of tokens before swap is updated.
     */
    event NumTokensBeforeSwapUpdated(uint256 newLimit);

    /**
     * @dev Emitted when swap and liquify by limit only is updated.
     */
    event SwapAndLiquifyByLimitOnlyUpdated(bool newValue);
}
