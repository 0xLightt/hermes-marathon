// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Start off with z at 1.
            z := 1

            // Used below to help find a nearby power of 2.
            let y := x

            // Find the lowest power of 2 that is at least sqrt(x).
            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y) // Like dividing by 2 ** 128.
                z := shl(64, z) // Like multiplying by 2 ** 64.
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z) // Like multiplying by 2 ** 32.
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z) // Like multiplying by 2 ** 16.
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z) // Like multiplying by 2 ** 8.
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z) // Like multiplying by 2 ** 4.
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z) // Like multiplying by 2 ** 2.
            }
            if iszero(lt(y, 0x8)) {
                // Equivalent to 2 ** z.
                z := shl(1, z)
            }

            // Shifting right by 1 is like dividing by 2.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // Compute a rounded down version of z.
            let zRoundDown := div(x, z)

            // If zRoundDown is smaller, use it.
            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}

// forked from https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol

// forked from https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/IMulticall.sol

/// @title Multicall interface
/// @notice Enables calling multiple methods in a single call to the contract
interface IMulticall {
    /// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
    /// @dev The `msg.value` should not be trusted for any method callable from multicall.
    /// @param data The encoded function data for each of the calls to make to this contract
    /// @return results The results from each of the calls passed in via data
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}

/// @title Multicall
/// @notice Enables calling multiple methods in a single call to the contract
abstract contract Multicall is IMulticall {
    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata data) public payable override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    event Debug(bool one, bool two, uint256 retsize);

    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol)
abstract contract ERC4626 is ERC20 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC20 public immutable asset;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, _asset.decimals()) {
        asset = _asset;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256);

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}

/// @notice A contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
contract Authority {
    /*//////////////////////////////////////////////////////////////
                            ROLE/USER STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice A mapping of authorization to an address
    mapping(address => mapping(address => bool)) public authentication;

    constructor() {
        authentication[address(this)][msg.sender] = true;
    }

    function addCaller(address user, address target) external {
        require(_canCall(msg.sender, address(this)), "Must be authenticated to call this function.");
        authentication[target][user] = true;
    }

    function removeCaller(address user, address target) external {
        require(_canCall(msg.sender, address(this)), "Must be authenticated to call this function.");
        authentication[target][user] = true;
    }

    /*//////////////////////////////////////////////////////////////
                           AUTHORIZATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function canCall(address user, address target) external view returns (bool) {
        return _canCall(user, target);
    }

    function _canCall(address user, address target) internal view returns (bool) {
        return authentication[target][user];
    }
}

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract Auth {
    event OwnerUpdated(address indexed user, address indexed newOwner);

    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;

    Authority public authority;

    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;

        emit OwnerUpdated(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender), "UNAUTHORIZED");

        _;
    }

    function isAuthorized(address user) internal view virtual returns (bool) {
        Authority auth = authority; // Memoizing authority saves us a warm SLOAD, around 100 gas.

        // Checking if the caller is the owner only after calling the authority saves gas in most cases, but be
        // aware that this makes protected functions uncallable even to the owner if the authority is out of order.
        return (address(auth) != address(0) && auth.canCall(user, address(this))) || user == owner;
    }

    function setAuthority(Authority newAuthority) public virtual {
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        require(msg.sender == owner || authority.canCall(msg.sender, address(this)));

        authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function setOwner(address newOwner) public virtual requiresAuth {
        owner = newOwner;

        emit OwnerUpdated(msg.sender, newOwner);
    }
}

/// @notice Safe unsigned integer casting library that reverts on overflow.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeCastLib.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol)
library SafeCastLib {
    function safeCastTo248(uint256 x) internal pure returns (uint248 y) {
        require(x < 1 << 248);

        y = uint248(x);
    }

    function safeCastTo224(uint256 x) internal pure returns (uint224 y) {
        require(x < 1 << 224);

        y = uint224(x);
    }

    function safeCastTo192(uint256 x) internal pure returns (uint192 y) {
        require(x < 1 << 192);

        y = uint192(x);
    }

    function safeCastTo160(uint256 x) internal pure returns (uint160 y) {
        require(x < 1 << 160);

        y = uint160(x);
    }

    function safeCastTo128(uint256 x) internal pure returns (uint128 y) {
        require(x < 1 << 128);

        y = uint128(x);
    }

    function safeCastTo96(uint256 x) internal pure returns (uint96 y) {
        require(x < 1 << 96);

        y = uint96(x);
    }

    function safeCastTo64(uint256 x) internal pure returns (uint64 y) {
        require(x < 1 << 64);

        y = uint64(x);
    }

    function safeCastTo32(uint256 x) internal pure returns (uint32 y) {
        require(x < 1 << 32);

        y = uint32(x);
    }

    function safeCastTo8(uint256 x) internal pure returns (uint8 y) {
        require(x < 1 << 8);

        y = uint8(x);
    }
}

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20NT {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

/** 
 @title Flywheel Dynamic Reward Stream
 @notice Determines rewards based on a dynamic reward stream.
         Rewards are transferred linearly over a "rewards cycle" to prevent gaming the reward distribution. 
         The reward source can be arbitrary logic, but most common is to "pass through" rewards from some other source.
         The getNextCycleRewards() hook should also transfer the next cycle's rewards to this contract to ensure proper accounting.
*/
contract RewardsDepot is Auth {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    ERC20 asset;
    address activeStrategy;
    address rewardsContract;

    constructor(
        ERC20 _asset,
        address _rewards,
        Authority _authority,
        address _owner
    ) Auth(_owner, _authority) {
        asset = _asset;
        rewardsContract = _rewards;
    }

    /*///////////////////////////////////////////////////////////////
                        REWARDS CONTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     @notice returns available reward amount and transfer them to rewardsContract.
     @param _activeStrategy the strategy to get rewards for.
     @return balance available reward amount for strategy.
    */
    function getRewards(ERC20NT _activeStrategy) external returns (uint256 balance) {
        require(address(msg.sender) == rewardsContract, "UNAUTHORIZED");

        if (address(_activeStrategy) == activeStrategy) {
            balance = asset.balanceOf(address(this));
            asset.transfer(rewardsContract, balance);
        } else {
            balance = 0;
        }
    }

    /**
     @notice set new active strategy to get next cycle's rewards.
     @param _activeStrategy the strategy to set as active.
    */
    function setActiveStrategy(address _activeStrategy) external requiresAuth {
        activeStrategy = _activeStrategy;
    }
}

/**
 @title Rewards Module for Flywheel
 @notice Flywheel is a general framework for managing token incentives.
         It takes reward streams to various *strategies* such as staking LP tokens and divides them among *users* of those strategies.

         The Rewards module is responsible for:
         * determining the ongoing reward amounts to entire strategies (core handles the logic for dividing among users)
         * actually holding rewards that are yet to be claimed

         The reward stream can follow arbitrary logic as long as the amount of rewards passed to flywheel core has been sent to this contract.

         Different module strategies include:
         * a static reward rate per second
         * a decaying reward rate
         * a dynamic just-in-time reward stream
         * liquid governance reward delegation (Curve Gauge style)

         SECURITY NOTE: The rewards strategy should be smooth and continuous, to prevent gaming the reward distribution by frontrunning.
 */
interface IFlywheelRewards {
    /**
     @notice calculate the rewards amount accrued to a strategy since the last update.
     @param strategy the strategy to accrue rewards for.
     @param lastUpdatedTimestamp the last time rewards were accrued for the strategy.
     @return rewards the amount of rewards accrued to the market
    */
    function getAccruedRewards(ERC20NT strategy, uint32 lastUpdatedTimestamp) external returns (uint256 rewards);

    /// @notice return the flywheel core address
    function flywheel() external view returns (FlywheelCore);

    /// @notice return the flywheel core address
    function rewardsDepot() external view returns (RewardsDepot);

    /// @notice return the reward token associated with flywheel core.
    function rewardToken() external view returns (ERC20);
}

/**
 @title Flywheel Core Incentives Manager
 @notice Flywheel is a general framework for managing token incentives.
         It takes reward streams to various *strategies* such as staking LP tokens and divides them among *users* of those strategies.

         The Core contract maintaings three important pieces of state:
         * the rewards index which determines how many rewards are owed per token per strategy. User indexes track how far behind the strategy they are to lazily calculate all catch-up rewards.
         * the accrued (unclaimed) rewards per user.
         * references to the booster and rewards module described below.

         Core does not manage any tokens directly. The rewards module maintains token balances, and approves core to pull transfer them to users when they claim.

         SECURITY NOTE: For maximum accuracy and to avoid exploits, rewards accrual should be notified atomically through the accrue hook. 
         Accrue should be called any time tokens are transferred, minted, or burned.
 */
contract FlywheelCore is Auth {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    /// @notice The token to reward
    ERC20 public immutable rewardToken;

    /// @notice append-only list of strategies added
    ERC20NT[] public allStrategies;

    /// @notice the rewards contract for managing streams
    IFlywheelRewards public flywheelRewards;

    constructor(
        ERC20 _rewardToken,
        IFlywheelRewards _flywheelRewards,
        address _owner,
        Authority _authority
    ) Auth(_owner, _authority) {
        rewardToken = _rewardToken;
        flywheelRewards = _flywheelRewards;
    }

    /*///////////////////////////////////////////////////////////////
                        ACCRUE/CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice Emitted when a user's rewards accrue to a given strategy.
      @param strategy the updated rewards strategy
      @param user the user of the rewards
      @param rewardsDelta how many new rewards accrued to the user
      @param rewardsIndex the market index for rewards per token accrued
    */
    event AccrueRewards(ERC20NT indexed strategy, address indexed user, uint256 rewardsDelta, uint256 rewardsIndex);

    /** 
      @notice Emitted when a user claims accrued rewards.
      @param user the user of the rewards
      @param amount the amount of rewards claimed
    */
    event ClaimRewards(address indexed user, uint256 amount);

    /// @notice The accrued but not yet transferred rewards for each user
    mapping(address => uint256) public rewardsAccrued;

    /** 
      @notice accrue rewards for a single user on a strategy
      @param strategy the strategy to accrue a user's rewards on
      @param user the user to be accrued
      @return the cumulative amount of rewards accrued to user (including prior)
    */
    function accrue(ERC20NT strategy, address user) public returns (uint256) {
        RewardsState memory state = strategyState[strategy];

        if (state.index == 0) return 0;

        state = accrueStrategy(strategy, state);
        return accrueUser(strategy, user, state);
    }

    /** 
      @notice accrue rewards for a two users on a strategy
      @param strategy the strategy to accrue a user's rewards on
      @param user the first user to be accrued
      @param user the second user to be accrued
      @return the cumulative amount of rewards accrued to the first user (including prior)
      @return the cumulative amount of rewards accrued to the second user (including prior)
    */
    function accrue(
        ERC20NT strategy,
        address user,
        address secondUser
    ) public returns (uint256, uint256) {
        RewardsState memory state = strategyState[strategy];

        if (state.index == 0) return (0, 0);

        state = accrueStrategy(strategy, state);
        return (accrueUser(strategy, user, state), accrueUser(strategy, secondUser, state));
    }

    /** 
      @notice claim rewards for a given user
      @param user the user claiming rewards
      @dev this function is public, and all rewards transfer to the user
    */
    function claimRewards(address user) external {
        uint256 accrued = rewardsAccrued[user];

        if (accrued != 0) {
            rewardsAccrued[user] = 0;

            rewardToken.safeTransferFrom(address(flywheelRewards), user, accrued);

            emit ClaimRewards(user, accrued);
        }
    }

    /*///////////////////////////////////////////////////////////////
                          ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice Emitted when a new strategy is added to flywheel by the admin
      @param newStrategy the new added strategy
    */
    event AddStrategy(address indexed newStrategy);

    /// @notice initialize a new strategy
    function addStrategyForRewards(ERC20NT strategy) external requiresAuth {
        _addStrategyForRewards(strategy);
    }

    function _addStrategyForRewards(ERC20NT strategy) internal {
        require(strategyState[strategy].index == 0, "strategy");
        strategyState[strategy] = RewardsState({index: ONE, lastUpdatedTimestamp: block.timestamp.safeCastTo32()});

        allStrategies.push(strategy);
        emit AddStrategy(address(strategy));
    }

    function getAllStrategies() external view returns (ERC20NT[] memory) {
        return allStrategies;
    }

    /** 
      @notice Emitted when the rewards module changes
      @param newFlywheelRewards the new rewards module
    */
    event FlywheelRewardsUpdate(address indexed newFlywheelRewards);

    /// @notice swap out the flywheel rewards contract
    function setFlywheelRewards(IFlywheelRewards newFlywheelRewards) external requiresAuth {
        uint256 oldRewardBalance = rewardToken.balanceOf(address(flywheelRewards));
        if (address(flywheelRewards) != address(0) && oldRewardBalance > 0) {
            rewardToken.safeTransferFrom(address(flywheelRewards), address(newFlywheelRewards), oldRewardBalance);
        }

        flywheelRewards = newFlywheelRewards;

        emit FlywheelRewardsUpdate(address(newFlywheelRewards));
    }

    /*///////////////////////////////////////////////////////////////
                    INTERNAL ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    struct RewardsState {
        /// @notice The strategy's last updated index
        uint224 index;
        /// @notice The timestamp the index was last updated at
        uint32 lastUpdatedTimestamp;
    }

    /// @notice the fixed point factor of flywheel
    uint224 public constant ONE = 1e18;

    /// @notice The strategy index and last updated per strategy
    mapping(ERC20NT => RewardsState) public strategyState;

    /// @notice user index per strategy
    mapping(ERC20NT => mapping(address => uint224)) public userIndex;

    /// @notice accumulate global rewards on a strategy
    function accrueStrategy(ERC20NT strategy, RewardsState memory state)
        private
        returns (RewardsState memory rewardsState)
    {
        // calculate accrued rewards through module
        uint256 strategyRewardsAccrued = flywheelRewards.getAccruedRewards(strategy, state.lastUpdatedTimestamp);

        rewardsState = state;
        if (strategyRewardsAccrued > 0) {
            // use the booster or token supply to calculate reward index denominator
            uint256 supplyTokens = strategy.totalSupply();

            uint224 deltaIndex;

            if (supplyTokens != 0) deltaIndex = ((strategyRewardsAccrued * ONE) / supplyTokens).safeCastTo224();

            // accumulate rewards per token onto the index, multiplied by fixed-point factor
            rewardsState = RewardsState({
                index: state.index + deltaIndex,
                lastUpdatedTimestamp: block.timestamp.safeCastTo32()
            });
            strategyState[strategy] = rewardsState;
        }
    }

    /// @notice accumulate rewards on a strategy for a specific user
    function accrueUser(
        ERC20NT strategy,
        address user,
        RewardsState memory state
    ) private returns (uint256) {
        // load indices
        uint224 strategyIndex = state.index;
        uint224 supplierIndex = userIndex[strategy][user];

        // sync user index to global
        userIndex[strategy][user] = strategyIndex;

        // if user hasn't yet accrued rewards, grant them interest from the strategy beginning if they have a balance
        // zero balances will have no effect other than syncing to global index
        if (supplierIndex == 0) {
            supplierIndex = ONE;
        }

        uint224 deltaIndex = strategyIndex - supplierIndex;
        // use the booster or token balance to calculate reward balance multiplier
        uint256 supplierTokens = strategy.balanceOf(user);

        // accumulate rewards by multiplying user tokens by rewardsPerToken index and adding on unclaimed
        uint256 supplierDelta = (supplierTokens * deltaIndex) / ONE;
        uint256 supplierAccrued = rewardsAccrued[user] + supplierDelta;

        rewardsAccrued[user] = supplierAccrued;

        emit AccrueRewards(strategy, user, supplierDelta, strategyIndex);

        return supplierAccrued;
    }
}

/**
@title Non Transfarable ERC20 to keep track of each week's Locked Hermes
@author Maia DAO
@notice Accrues rewards in before balance change, only when minting in this case. 
        Rewards need to be accrued either through here or flywheel and collected through the flywheel.
*/

contract ERC20MarathonHermes is ERC20NT, Auth {
    using FixedPointMathLib for uint256;

    /// @notice reward manager
    FlywheelCore public flywheel;

    constructor(
        Authority _authority,
        address _owner,
        FlywheelCore _flywheel
    ) ERC20NT("Marathon Hermes", "mHermes", 18) Auth(_owner, _authority) {
        flywheel = _flywheel;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice simple re-entrancy check
    uint256 internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                               REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice accrue rewards for a single user
      @param user the user to be accrued
      @return the cumulative amount of rewards accrued to user (including prior)
    */
    function accrue(address user) external lock returns (uint256) {
        return _accrue(user);
    }

    /** 
      @notice accrue rewards for a single user
      @param user the user to be accrued
      @return the cumulative amount of rewards accrued to user (including prior)
    */
    function _accrue(address user) internal returns (uint256) {
        return flywheel.accrue(this, user);
    }

    /** 
      @notice accrue rewards for a two users
      @param user the first user to be accrued
      @param user the second user to be accrued
      @return the cumulative amount of rewards accrued to the first user (including prior)
      @return the cumulative amount of rewards accrued to the second user (including prior)
    */
    function accrue(address user, address secondUser) external returns (uint256, uint256) {
        return flywheel.accrue(this, user, secondUser);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     @notice accrues rewards and mints new amount to address.
     @param to address to receive.
     @param amount amount to mint.
    */
    function stake(address to, uint256 amount) external lock requiresAuth {
        _accrue(to);
        _mint(to, amount);
    }
}

/** 
 @title Flywheel Reward Module
 @notice Determines how many rewards accrue to each strategy globally over a given time period.
 @dev approves the flywheel core for the reward token to allow balances to be managed by the module but claimed from core.
*/
abstract contract BaseFlywheelRewards is IFlywheelRewards {
    using SafeTransferLib for ERC20;

    /// @notice thrown when caller is not the flywheel
    error FlywheelError();

    /// @notice the reward token paid
    ERC20 public immutable override rewardToken;

    /// @notice the flywheel core contract
    FlywheelCore public immutable override flywheel;

    constructor(FlywheelCore _flywheel) {
        flywheel = _flywheel;
        ERC20 _rewardToken = _flywheel.rewardToken();
        rewardToken = _rewardToken;

        _rewardToken.safeApprove(address(_flywheel), type(uint256).max);
    }

    modifier onlyFlywheel() {
        if (msg.sender != address(flywheel)) revert FlywheelError();
        _;
    }
}

/** 
 @title Flywheel Dynamic Reward Stream
 @notice Determines rewards based on a dynamic reward stream.
         Rewards are transferred linearly over a "rewards cycle" to prevent gaming the reward distribution. 
         The reward source can be arbitrary logic, but most common is to "pass through" rewards from some other source.
         The getNextCycleRewards() hook should also transfer the next cycle's rewards to this contract to ensure proper accounting.
*/
abstract contract FlywheelDynamicRewards is BaseFlywheelRewards {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    event NewRewardsCycle(uint32 indexed start, uint32 indexed end, uint192 reward);

    /// @notice the length of a rewards cycle
    uint32 public immutable rewardsCycleLength;

    struct RewardsCycle {
        uint32 start;
        uint32 end;
        uint192 reward;
    }

    mapping(ERC20NT => RewardsCycle) public rewardsCycle;

    constructor(FlywheelCore _flywheel, uint32 _rewardsCycleLength) BaseFlywheelRewards(_flywheel) {
        rewardsCycleLength = _rewardsCycleLength;
    }

    /**
     @notice calculate the rewards amount accrued to a strategy since the last update.
     @param strategy the strategy to accrue rewards for.
     @param lastUpdatedTimestamp the last time rewards were accrued for the strategy.
     @return amount the amount of rewards accrued to the market
    */
    function getAccruedRewards(ERC20NT strategy, uint32 lastUpdatedTimestamp)
        external
        override
        onlyFlywheel
        returns (uint256 amount)
    {
        RewardsCycle memory cycle = rewardsCycle[strategy];

        uint32 timestamp = block.timestamp.safeCastTo32();

        uint32 latest = timestamp >= cycle.end ? cycle.end : timestamp;
        uint32 earliest = lastUpdatedTimestamp <= cycle.start ? cycle.start : lastUpdatedTimestamp;
        if (cycle.end != 0) {
            amount = (cycle.reward * (latest - earliest)) / (cycle.end - cycle.start);
            assert(amount <= cycle.reward); // should never happen because latest <= cycle.end and earliest >= cycle.start
        }
        // if cycle has ended, reset cycle and transfer all available
        if (timestamp >= cycle.end) {
            uint32 end = ((timestamp + rewardsCycleLength) / rewardsCycleLength) * rewardsCycleLength;
            uint192 rewards = getNextCycleRewards(strategy);

            // reset for next cycle
            rewardsCycle[strategy] = RewardsCycle({start: timestamp, end: end, reward: rewards});

            emit NewRewardsCycle(timestamp, end, rewards);
        }
    }

    /**
     @notice get and transfer next week's rewards.
     @param strategy the strategy to accrue rewards for.
     @return amount the amount of tokens transferred.
     */
    function getNextCycleRewards(ERC20NT strategy) internal virtual returns (uint192);
}

/** 
 @title Flywheel Dynamic Reward Stream
 @notice Determines rewards based on a dynamic reward stream.
         Rewards are transferred linearly over a "rewards cycle" to prevent gaming the reward distribution. 
         The reward source can be arbitrary logic, but most common is to "pass through" rewards from some other source.
         The getNextCycleRewards() hook should also transfer the next cycle's rewards to this contract to ensure proper accounting.
*/
contract HermesDynamicRewards is FlywheelDynamicRewards, Auth {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    /// @notice RewardsDepot to collect rewards from
    RewardsDepot public rewardsDepot;

    constructor(
        FlywheelCore _flywheel,
        uint32 _rewardsCycleLength,
        Authority _authority,
        address _owner
    ) FlywheelDynamicRewards(_flywheel, _rewardsCycleLength) Auth(_owner, _authority) {}

    /**
     @notice get and transfer next week's rewards
     @param strategy the strategy to accrue rewards for
     @return amount the amount of tokens transferred
     */
    function getNextCycleRewards(ERC20NT strategy) internal override returns (uint192) {
        return uint192(rewardsDepot.getRewards(strategy));
    }

    /**
     @notice set new rewards depot
     @param _rewardsDepot the new rewards depot to set
     */
    function setRewardsDepot(RewardsDepot _rewardsDepot) external requiresAuth {
        rewardsDepot = _rewardsDepot;
    }
}

interface ve {
    function create_lock_for(
        uint256 _value,
        uint256 _lock_duration,
        address _to
    ) external returns (uint256);

    function increase_amount(uint256 _tokenId, uint256 _value) external;

    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external;

    function locked__end(uint256 _tokenId) external view returns (uint256);
}

/**
@title Base Contract to keep track and distribute rewards to weekly new veHermes lockers
@author Maia DAO
@notice Each epoch mint's new Non Transfarable ERC20 every week to keep track of new lockers.
        Adds token as new strategy to flywheel core, flywheelRewards and rewardsDepot.
*/

contract MarathonLocker {
    using FixedPointMathLib for uint256;

    /// @notice reward Manager
    FlywheelCore public immutable flywheel;

    /// @notice reward Streamer
    HermesDynamicRewards public immutable flywheelRewards;

    /// @notice RewardsDepot
    RewardsDepot public immutable rewardsDepot;

    /// @notice underlying to lock
    ERC20 public immutable hermes;
    /// @notice locker to lock underlying
    address public immutable veHermes;

    uint256 internal immutable MAX_LOCK = 126144000;
    uint256 internal immutable WEEK = 1 weeks;

    /// @notice this epoch's start
    uint256 public epochStart;
    /// @notice this epoch's strategy to keep track of rewards
    ERC20MarathonHermes public currentStrategy;

    constructor(
        address _hermes,
        address _veHermes,
        ERC20 _rewardToken
    ) {
        hermes = ERC20(_hermes);
        veHermes = _veHermes;
        hermes.approve(veHermes, type(uint256).max);

        Authority authority = Authority(address(0));

        flywheel = new FlywheelCore(_rewardToken, HermesDynamicRewards(address(0)), address(this), authority);

        flywheelRewards = new HermesDynamicRewards(flywheel, uint32(WEEK), authority, address(this));

        flywheel.setFlywheelRewards(flywheelRewards);

        rewardsDepot = new RewardsDepot(_rewardToken, address(flywheelRewards), authority, address(this));

        flywheelRewards.setRewardsDepot(rewardsDepot);

        _newEpoch();
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice simple re-entrancy check
    uint256 internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                                LOCK
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice Deposit amount HERMES for msg.sender and lock for 4 years
      @param amount Amount to deposit
    */
    function createLock(uint256 amount) external lock {
        _newEpoch();

        hermes.transferFrom(msg.sender, address(this), amount);
        ve(veHermes).create_lock_for(amount, MAX_LOCK, msg.sender);

        currentStrategy.stake(msg.sender, amount);
    }

    /** 
      @notice Deposit amount HERMES for tokenId and increase unlock time for 4 years
      @param tokenId tokenId to deposit and increase unlock time
      @param amount Amount to deposit
    */
    function increaseTimeAndLock(uint256 tokenId, uint256 amount) external lock {
        _newEpoch();

        hermes.transferFrom(msg.sender, address(this), amount);
        ve(veHermes).increase_unlock_time(tokenId, MAX_LOCK);
        ve(veHermes).increase_amount(tokenId, amount);

        currentStrategy.stake(msg.sender, amount);
    }

    /** 
      @notice Deposit amount HERMES for tokenId
      @param tokenId tokenId to deposit
      @param amount Amount to deposit
    */
    function increaseLock(uint256 tokenId, uint256 amount) external lock {
        _newEpoch();

        uint256 _max = ((block.timestamp + MAX_LOCK) / WEEK) * WEEK;
        require(ve(veHermes).locked__end(tokenId) == _max, "Lock is too short");

        hermes.transferFrom(msg.sender, address(this), amount);
        ve(veHermes).increase_amount(tokenId, amount);

        currentStrategy.stake(msg.sender, amount);
    }

    /** 
      @notice if new epoch then start it and create new token to keep track of new weeks' lockers.
              add token as new strategy to flywheel core, flywheelRewards and rewardsDepot.
    */
    function _newEpoch() internal {
        uint256 _thisEpoch = (block.timestamp / WEEK) * WEEK;

        if (_thisEpoch > epochStart) {
            if (address(currentStrategy) != address(0)) currentStrategy.accrue(msg.sender);
            ERC20MarathonHermes _newStrategy = new ERC20MarathonHermes(Authority(address(0)), address(this), flywheel);
            currentStrategy = _newStrategy;
            rewardsDepot.setActiveStrategy(address(_newStrategy));
            flywheel.addStrategyForRewards(_newStrategy);

            epochStart = _thisEpoch;

            emit AddEpoch(address(_newStrategy), _thisEpoch);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice Emitted when a new strategy is added to flywheel by the admin
      @param newFlywheel the new added strategy
      @param epochStart the epoch starting timestamp
    */
    event AddEpoch(address indexed newFlywheel, uint256 indexed epochStart);
}

// import { Types } from "./Types.sol";
// import { Hashing } from "./Hashing.sol";

/**
 * @custom:attribution https://github.com/bakaoh/solidity-rlp-encode
 * @title RLPWriter
 * @author RLPWriter is a library for encoding Solidity types to RLP bytes. Adapted from Bakaoh's
 *         RLPEncode library (https://github.com/bakaoh/solidity-rlp-encode) with minor
 *         modifications to improve legibility.
 */
library RLPWriter {
    /**
     * @notice RLP encodes a byte string.
     *
     * @param _in The byte string to encode.
     *
     * @return The RLP encoded string in bytes.
     */
    function writeBytes(bytes memory _in) internal pure returns (bytes memory) {
        bytes memory encoded;

        if (_in.length == 1 && uint8(_in[0]) < 128) {
            encoded = _in;
        } else {
            encoded = abi.encodePacked(_writeLength(_in.length, 128), _in);
        }

        return encoded;
    }

    /**
     * @notice RLP encodes a list of RLP encoded byte byte strings.
     *
     * @param _in The list of RLP encoded byte strings.
     *
     * @return The RLP encoded list of items in bytes.
     */
    function writeList(bytes[] memory _in) internal pure returns (bytes memory) {
        bytes memory list = _flatten(_in);
        return abi.encodePacked(_writeLength(list.length, 192), list);
    }

    /**
     * @notice RLP encodes a string.
     *
     * @param _in The string to encode.
     *
     * @return The RLP encoded string in bytes.
     */
    function writeString(string memory _in) internal pure returns (bytes memory) {
        return writeBytes(bytes(_in));
    }

    /**
     * @notice RLP encodes an address.
     *
     * @param _in The address to encode.
     *
     * @return The RLP encoded address in bytes.
     */
    function writeAddress(address _in) internal pure returns (bytes memory) {
        return writeBytes(abi.encodePacked(_in));
    }

    /**
     * @notice RLP encodes a uint.
     *
     * @param _in The uint256 to encode.
     *
     * @return The RLP encoded uint256 in bytes.
     */
    function writeUint(uint256 _in) internal pure returns (bytes memory) {
        return writeBytes(_toBinary(_in));
    }

    /**
     * @notice RLP encodes a bool.
     *
     * @param _in The bool to encode.
     *
     * @return The RLP encoded bool in bytes.
     */
    function writeBool(bool _in) internal pure returns (bytes memory) {
        bytes memory encoded = new bytes(1);
        encoded[0] = (_in ? bytes1(0x01) : bytes1(0x80));
        return encoded;
    }

    /**
     * @notice Encode the first byte and then the `len` in binary form if `length` is more than 55.
     *
     * @param _len    The length of the string or the payload.
     * @param _offset 128 if item is string, 192 if item is list.
     *
     * @return RLP encoded bytes.
     */
    function _writeLength(uint256 _len, uint256 _offset) private pure returns (bytes memory) {
        bytes memory encoded;

        if (_len < 56) {
            encoded = new bytes(1);
            encoded[0] = bytes1(uint8(_len) + uint8(_offset));
        } else {
            uint256 lenLen;
            uint256 i = 1;
            while (_len / i != 0) {
                lenLen++;
                i *= 256;
            }

            encoded = new bytes(lenLen + 1);
            encoded[0] = bytes1(uint8(lenLen) + uint8(_offset) + 55);
            for (i = 1; i <= lenLen; i++) {
                encoded[i] = bytes1(uint8((_len / (256**(lenLen - i))) % 256));
            }
        }

        return encoded;
    }

    /**
     * @notice Encode integer in big endian binary form with no leading zeroes.
     *
     * @param _x The integer to encode.
     *
     * @return RLP encoded bytes.
     */
    function _toBinary(uint256 _x) private pure returns (bytes memory) {
        bytes memory b = abi.encodePacked(_x);

        uint256 i = 0;
        for (; i < 32; i++) {
            if (b[i] != 0) {
                break;
            }
        }

        bytes memory res = new bytes(32 - i);
        for (uint256 j = 0; j < res.length; j++) {
            res[j] = b[i++];
        }

        return res;
    }

    /**
     * @custom:attribution https://github.com/Arachnid/solidity-stringutils
     * @notice Copies a piece of memory to another location.
     *
     * @param _dest Destination location.
     * @param _src  Source location.
     * @param _len  Length of memory to copy.
     */
    function _memcpy(
        uint256 _dest,
        uint256 _src,
        uint256 _len
    ) private pure {
        uint256 dest = _dest;
        uint256 src = _src;
        uint256 len = _len;

        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        uint256 mask;
        unchecked {
            mask = 256**(32 - len) - 1;
        }
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /**
     * @custom:attribution https://github.com/sammayo/solidity-rlp-encoder
     * @notice Flattens a list of byte strings into one byte string.
     *
     * @param _list List of byte strings to flatten.
     *
     * @return The flattened byte string.
     */
    function _flatten(bytes[] memory _list) private pure returns (bytes memory) {
        if (_list.length == 0) {
            return new bytes(0);
        }

        uint256 len;
        uint256 i = 0;
        for (; i < _list.length; i++) {
            len += _list[i].length;
        }

        bytes memory flattened = new bytes(len);
        uint256 flattenedPtr;
        assembly {
            flattenedPtr := add(flattened, 0x20)
        }

        for (i = 0; i < _list.length; i++) {
            bytes memory item = _list[i];

            uint256 listPtr;
            assembly {
                listPtr := add(item, 0x20)
            }

            _memcpy(flattenedPtr, listPtr, item.length);
            flattenedPtr += _list[i].length;
        }

        return flattened;
    }
}

/**
 * @custom:attribution https://github.com/hamdiallam/Solidity-RLP
 * @title RLPReader
 * @notice RLPReader is a library for parsing RLP-encoded byte arrays into Solidity types. Adapted
 *         from Solidity-RLP (https://github.com/hamdiallam/Solidity-RLP) by Hamdi Allam with
 *         various tweaks to improve readability.
 */
library RLPReader {
    /**
     * Custom pointer type to avoid confusion between pointers and uint256s.
     */
    type MemoryPointer is uint256;

    /**
     * @notice RLP item types.
     *
     * @custom:value DATA_ITEM Represents an RLP data item (NOT a list).
     * @custom:value LIST_ITEM Represents an RLP list item.
     */
    enum RLPItemType {
        DATA_ITEM,
        LIST_ITEM
    }

    /**
     * @notice Struct representing an RLP item.
     */
    struct RLPItem {
        uint256 length;
        MemoryPointer ptr;
    }

    /**
     * @notice Converts bytes to a reference to memory position and length.
     *
     * @param _in Input bytes to convert.
     *
     * @return Output memory reference.
     */
    function toRLPItem(bytes memory _in) internal pure returns (RLPItem memory) {
        // Empty arrays are not RLP items.
        require(
            _in.length > 0,
            "RLPReader: length of an RLP item must be greater than zero to be decodable"
        );

        MemoryPointer ptr;
        assembly {
            ptr := add(_in, 32)
        }

        return RLPItem({ length: _in.length, ptr: ptr });
    }

    /**
     * @notice Reads an RLP list value into a list of RLP items.
     *
     * @param _in RLP list value.
     * @param _maxListLength Max list length that this library will accept.
     *
     * @return Decoded RLP list items.
     */
    function readList(RLPItem memory _in, uint256 _maxListLength) internal pure returns (RLPItem[] memory) {
        (uint256 listOffset, uint256 listLength, RLPItemType itemType) = _decodeLength(_in);

        require(
            itemType == RLPItemType.LIST_ITEM,
            "RLPReader: decoded item type for list is not a list item"
        );

        require(
            listOffset + listLength == _in.length,
            "RLPReader: list item has an invalid data remainder"
        );

        // Solidity in-memory arrays can't be increased in size, but *can* be decreased in size by
        // writing to the length. Since we can't know the number of RLP items without looping over
        // the entire input, we'd have to loop twice to accurately size this array. It's easier to
        // simply set a reasonable maximum list length and decrease the size before we finish.
        RLPItem[] memory out = new RLPItem[](_maxListLength);

        uint256 itemCount = 0;
        uint256 offset = listOffset;
        while (offset < _in.length) {
            (uint256 itemOffset, uint256 itemLength, ) = _decodeLength(
                RLPItem({
                    length: _in.length - offset,
                    ptr: MemoryPointer.wrap(MemoryPointer.unwrap(_in.ptr) + offset)
                })
            );

            // We don't need to check itemCount < out.length explicitly because Solidity already
            // handles this check on our behalf, we'd just be wasting gas.
            out[itemCount] = RLPItem({
                length: itemLength + itemOffset,
                ptr: MemoryPointer.wrap(MemoryPointer.unwrap(_in.ptr) + offset)
            });

            itemCount += 1;
            offset += itemOffset + itemLength;
        }

        // Decrease the array size to match the actual item count.
        assembly {
            mstore(out, itemCount)
        }

        return out;
    }

    /**
     * @notice Reads an RLP list value into a list of RLP items.
     *
     * @param _in RLP list value.
     *
     * @return Decoded RLP list items.
     */
    function readList(bytes memory _in, uint256 _maxListLength) internal pure returns (RLPItem[] memory) {
        return readList(toRLPItem(_in), _maxListLength);
    }

    /**
     * @notice Reads an RLP bytes value into bytes.
     *
     * @param _in RLP bytes value.
     *
     * @return Decoded bytes.
     */
    function readBytes(RLPItem memory _in) internal pure returns (bytes memory) {
        (uint256 itemOffset, uint256 itemLength, RLPItemType itemType) = _decodeLength(_in);

        require(
            itemType == RLPItemType.DATA_ITEM,
            "RLPReader: decoded item type for bytes is not a data item"
        );

        require(
            _in.length == itemOffset + itemLength,
            "RLPReader: bytes value contains an invalid remainder"
        );

        return _copy(_in.ptr, itemOffset, itemLength);
    }

    /**
     * @notice Reads an RLP bytes value into bytes.
     *
     * @param _in RLP bytes value.
     *
     * @return Decoded bytes.
     */
    function readBytes(bytes memory _in) internal pure returns (bytes memory) {
        return readBytes(toRLPItem(_in));
    }

    /**
     * @notice Reads the raw bytes of an RLP item.
     *
     * @param _in RLP item to read.
     *
     * @return Raw RLP bytes.
     */
    function readRawBytes(RLPItem memory _in) internal pure returns (bytes memory) {
        return _copy(_in.ptr, 0, _in.length);
    }

    /**
     * @notice Decodes the length of an RLP item.
     *
     * @param _in RLP item to decode.
     *
     * @return Offset of the encoded data.
     * @return Length of the encoded data.
     * @return RLP item type (LIST_ITEM or DATA_ITEM).
     */
    function _decodeLength(RLPItem memory _in)
        private
        pure
        returns (
            uint256,
            uint256,
            RLPItemType
        )
    {
        // Short-circuit if there's nothing to decode, note that we perform this check when
        // the user creates an RLP item via toRLPItem, but it's always possible for them to bypass
        // that function and create an RLP item directly. So we need to check this anyway.
        require(
            _in.length > 0,
            "RLPReader: length of an RLP item must be greater than zero to be decodable"
        );

        MemoryPointer ptr = _in.ptr;
        uint256 prefix;
        assembly {
            prefix := byte(0, mload(ptr))
        }

        if (prefix <= 0x7f) {
            // Single byte.
            return (0, 1, RLPItemType.DATA_ITEM);
        } else if (prefix <= 0xb7) {
            // Short string.

            // slither-disable-next-line variable-scope
            uint256 strLen = prefix - 0x80;

            require(
                _in.length > strLen,
                "RLPReader: length of content must be greater than string length (short string)"
            );

            bytes1 firstByteOfContent;
            assembly {
                firstByteOfContent := and(mload(add(ptr, 1)), shl(248, 0xff))
            }

            require(
                strLen != 1 || firstByteOfContent >= 0x80,
                "RLPReader: invalid prefix, single byte < 0x80 are not prefixed (short string)"
            );

            return (1, strLen, RLPItemType.DATA_ITEM);
        } else if (prefix <= 0xbf) {
            // Long string.
            uint256 lenOfStrLen = prefix - 0xb7;

            require(
                _in.length > lenOfStrLen,
                "RLPReader: length of content must be > than length of string length (long string)"
            );

            bytes1 firstByteOfContent;
            assembly {
                firstByteOfContent := and(mload(add(ptr, 1)), shl(248, 0xff))
            }

            require(
                firstByteOfContent != 0x00,
                "RLPReader: length of content must not have any leading zeros (long string)"
            );

            uint256 strLen;
            assembly {
                strLen := shr(sub(256, mul(8, lenOfStrLen)), mload(add(ptr, 1)))
            }

            require(
                strLen > 55,
                "RLPReader: length of content must be greater than 55 bytes (long string)"
            );

            require(
                _in.length > lenOfStrLen + strLen,
                "RLPReader: length of content must be greater than total length (long string)"
            );

            return (1 + lenOfStrLen, strLen, RLPItemType.DATA_ITEM);
        } else if (prefix <= 0xf7) {
            // Short list.
            // slither-disable-next-line variable-scope
            uint256 listLen = prefix - 0xc0;

            require(
                _in.length > listLen,
                "RLPReader: length of content must be greater than list length (short list)"
            );

            return (1, listLen, RLPItemType.LIST_ITEM);
        } else {
            // Long list.
            uint256 lenOfListLen = prefix - 0xf7;

            require(
                _in.length > lenOfListLen,
                "RLPReader: length of content must be > than length of list length (long list)"
            );

            bytes1 firstByteOfContent;
            assembly {
                firstByteOfContent := and(mload(add(ptr, 1)), shl(248, 0xff))
            }

            require(
                firstByteOfContent != 0x00,
                "RLPReader: length of content must not have any leading zeros (long list)"
            );

            uint256 listLen;
            assembly {
                listLen := shr(sub(256, mul(8, lenOfListLen)), mload(add(ptr, 1)))
            }

            require(
                listLen > 55,
                "RLPReader: length of content must be greater than 55 bytes (long list)"
            );

            require(
                _in.length > lenOfListLen + listLen,
                "RLPReader: length of content must be greater than total length (long list)"
            );

            return (1 + lenOfListLen, listLen, RLPItemType.LIST_ITEM);
        }
    }

    /**
     * @notice Copies the bytes from a memory location.
     *
     * @param _src    Pointer to the location to read from.
     * @param _offset Offset to start reading from.
     * @param _length Number of bytes to read.
     *
     * @return Copied bytes.
     */
    function _copy(
        MemoryPointer _src,
        uint256 _offset,
        uint256 _length
    ) private pure returns (bytes memory) {
        bytes memory out = new bytes(_length);
        if (_length == 0) {
            return out;
        }

        // Mostly based on Solidity's copy_memory_to_memory:
        // solhint-disable max-line-length
        // https://github.com/ethereum/solidity/blob/34dd30d71b4da730488be72ff6af7083cf2a91f6/libsolidity/codegen/YulUtilFunctions.cpp#L102-L114
        uint256 src = MemoryPointer.unwrap(_src) + _offset;
        assembly {
            let dest := add(out, 32)
            let i := 0
            for {

            } lt(i, _length) {
                i := add(i, 32)
            } {
                mstore(add(dest, i), mload(add(src, i)))
            }

            if gt(i, _length) {
                mstore(add(dest, _length), 0)
            }
        }

        return out;
    }
}

/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for writing to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */
library BufferChainlink {
  /**
   * @dev Represents a mutable buffer. Buffers have a current value (buf) and
   *      a capacity. The capacity may be longer than the current value, in
   *      which case it can be extended without the need to allocate more memory.
   */
  struct buffer {
    bytes buf;
    uint256 capacity;
  }

  /**
   * @dev Initializes a buffer with an initial capacity.
   * @param buf The buffer to initialize.
   * @param capacity The number of bytes of space to allocate the buffer.
   * @return The buffer, for chaining.
   */
  function init(buffer memory buf, uint256 capacity) internal pure returns (buffer memory) {
    if (capacity % 32 != 0) {
      capacity += 32 - (capacity % 32);
    }
    // Allocate space for the buffer data
    buf.capacity = capacity;
    assembly {
      let ptr := mload(0x40)
      mstore(buf, ptr)
      mstore(ptr, 0)
      mstore(0x40, add(32, add(ptr, capacity)))
    }
    return buf;
  }

  /**
   * @dev Initializes a new buffer from an existing bytes object.
   *      Changes to the buffer may mutate the original value.
   * @param b The bytes object to initialize the buffer with.
   * @return A new buffer.
   */
  function fromBytes(bytes memory b) internal pure returns (buffer memory) {
    buffer memory buf;
    buf.buf = b;
    buf.capacity = b.length;
    return buf;
  }

  function resize(buffer memory buf, uint256 capacity) private pure {
    bytes memory oldbuf = buf.buf;
    init(buf, capacity);
    append(buf, oldbuf);
  }

  function max(uint256 a, uint256 b) private pure returns (uint256) {
    if (a > b) {
      return a;
    }
    return b;
  }

  /**
   * @dev Sets buffer length to 0.
   * @param buf The buffer to truncate.
   * @return The original buffer, for chaining..
   */
  function truncate(buffer memory buf) internal pure returns (buffer memory) {
    assembly {
      let bufptr := mload(buf)
      mstore(bufptr, 0)
    }
    return buf;
  }

  /**
   * @dev Writes a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The start offset to write to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    require(len <= data.length);

    if (off + len > buf.capacity) {
      resize(buf, max(buf.capacity, len + off) * 2);
    }

    uint256 dest;
    uint256 src;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Start address = buffer address + offset + sizeof(buffer length)
      dest := add(add(bufptr, 32), off)
      // Update buffer length if we're extending it
      if gt(add(len, off), buflen) {
        mstore(bufptr, add(len, off))
      }
      src := add(data, 32)
    }

    // Copy word-length chunks while possible
    for (; len >= 32; len -= 32) {
      assembly {
        mstore(dest, mload(src))
      }
      dest += 32;
      src += 32;
    }

    // Copy remaining bytes
    unchecked {
      uint256 mask = (256**(32 - len)) - 1;
      assembly {
        let srcpart := and(mload(src), not(mask))
        let destpart := and(mload(dest), mask)
        mstore(dest, or(destpart, srcpart))
      }
    }

    return buf;
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function append(
    buffer memory buf,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, len);
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, data.length);
  }

  /**
   * @dev Writes a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write the byte at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeUint8(
    buffer memory buf,
    uint256 off,
    uint8 data
  ) internal pure returns (buffer memory) {
    if (off >= buf.capacity) {
      resize(buf, buf.capacity * 2);
    }

    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Address = buffer address + sizeof(buffer length) + off
      let dest := add(add(bufptr, off), 32)
      mstore8(dest, data)
      // Update buffer length if we extended it
      if eq(off, buflen) {
        mstore(bufptr, add(buflen, 1))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendUint8(buffer memory buf, uint8 data) internal pure returns (buffer memory) {
    return writeUint8(buf, buf.buf.length, data);
  }

  /**
   * @dev Writes up to 32 bytes to the buffer. Resizes if doing so would
   *      exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (left-aligned).
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes32 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    unchecked {
      uint256 mask = (256**len) - 1;
      // Right-align data
      data = data >> (8 * (32 - len));
      assembly {
        // Memory address of the buffer data
        let bufptr := mload(buf)
        // Address = buffer address + sizeof(buffer length) + off + len
        let dest := add(add(bufptr, off), len)
        mstore(dest, or(and(mload(dest), not(mask)), data))
        // Update buffer length if we extended it
        if gt(add(off, len), mload(bufptr)) {
          mstore(bufptr, add(off, len))
        }
      }
    }
    return buf;
  }

  /**
   * @dev Writes a bytes20 to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeBytes20(
    buffer memory buf,
    uint256 off,
    bytes20 data
  ) internal pure returns (buffer memory) {
    return write(buf, off, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chhaining.
   */
  function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, 32);
  }

  /**
   * @dev Writes an integer to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (right-aligned).
   * @return The original buffer, for chaining.
   */
  function writeInt(
    buffer memory buf,
    uint256 off,
    uint256 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    uint256 mask = (256**len) - 1;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Address = buffer address + off + sizeof(buffer length) + len
      let dest := add(add(bufptr, off), len)
      mstore(dest, or(and(mload(dest), not(mask)), data))
      // Update buffer length if we extended it
      if gt(add(off, len), mload(bufptr)) {
        mstore(bufptr, add(off, len))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the end of the buffer. Resizes if doing so would
   * exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer.
   */
  function appendInt(
    buffer memory buf,
    uint256 data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return writeInt(buf, buf.buf.length, data, len);
  }
}

/**
 * @title Encoding
 * @notice Encoding handles Optimism's various different encoding schemes.
 */
library Encoding {
  using BufferChainlink for BufferChainlink.buffer;

    /**
     * @notice Encode provided calldata using RLP. Provides cheaper external calls in L2 networks.
     *
     * @param data 1 Byte Function Id and Calladata to encode.
     * @param offset Offset for calldata location in ´data´.
     *
     * @dev data is comprised the calldata parameters using standard abi encoding. 
     *
     * @return RLP encoded tx calldata.
     **/
    function encodeCallData(bytes memory data, uint256 offset) internal pure returns (bytes memory) {
        uint length = data.length;

        // Initialize byte list for encoding
        bytes[] memory buffer = new bytes[](length);

        uint256 positon;
        // Reads concsucitve 32 bytes starting from offset
        for (uint256 i = offset + 32; i <= length; ) {

            uint256 slot;
            assembly {
                slot := mload(add(data, i)) // Get next 32 bytes
            }

            // Encode and add extracted 32 bytes buffer
            buffer[positon] = RLPWriter.writeUint(slot);

            unchecked {
                i += 32;
                positon += 1;
            }
        }

        // return encoded byte list
        return RLPWriter.writeList(buffer);
    }

    /**
     * @notice Decode provided RLP encoded data into calldata. Provides cheaper external calls in L2 networks.
     *
     * @param data RLP encoded calladata to decode.
     *
     * @dev data is comprised of the calldata parameters without padding.
     *
     * @return bytes standard abi encoded tx calldata.
     **/
    function decodeCallData(bytes memory data, uint256 maxListLength) internal pure returns (bytes memory) {
        // Get RLP item list from data
        RLPReader.RLPItem[] memory items = RLPReader.readList(data, maxListLength);

        uint256 length = items.length;

        BufferChainlink.buffer memory buffer;
        // Initialize buffer with 32 bytes for each item
        BufferChainlink.init(buffer, length * 32);

        for (uint256 i = 0; i < length; ) {
            bytes memory slot = RLPReader.readBytes(items[i]);

            // Right-shift signifcant bytes to restore padding
            bytes32 val = bytes32(slot) >> (256-slot.length*8);

            // Add extracted 32 bytes buffer
            buffer.appendBytes32(val);

            unchecked {
                i++;
            }
        }
        return buffer.buf;
    }
}

contract ClaimHelper {
    FlywheelCore private immutable flywheel;
    MarathonLocker private immutable marathonLocker;
    mapping(uint256 => ERC20MarathonHermes) private marathonHermesPerEpoch;

    uint256 internal immutable WEEK = 1 weeks;

    /// @notice this epoch's start
    uint256 public epochStart;
    /// @notice current epoch
    uint256 public currentEpoch;

    constructor(FlywheelCore _flywheel, MarathonLocker _marathonLocker) {
        flywheel = _flywheel;
        marathonLocker = _marathonLocker;
        _newEpoch();
    }

    fallback() external {
        uint256[] memory epochs = abi.decode(Encoding.decodeCallData(msg.data, currentEpoch), (uint256[]));
        _accrueAndClaimRewards(epochs);
    }

    /// @notice accrue and claim outstanding rewards for msg.sender
    function accrueAndClaimRewards(uint256[] memory epochs) external {
        _accrueAndClaimRewards(epochs);
    }

    /// @notice accrue and claim outstanding rewards for msg.sender
    function _accrueAndClaimRewards(uint256[] memory epochs) internal {
        _newEpoch();

        address user = msg.sender;
        uint256 length = epochs.length;
        for (uint256 i = 0; i < length; ) {
            flywheel.accrue(marathonHermesPerEpoch[epochs[i]], user);
            unchecked {
                i++;
            }
        }
        flywheel.claimRewards(user);
    }

    /** 
      @notice if new epoch then start it and create new token to keep track of new weeks' lockers.
              add token as new strategy to flywheel core, flywheelRewards and rewardsDepot.
    */
    function _newEpoch() internal {
        uint256 _thisEpoch = (block.timestamp / WEEK) * WEEK;

        if (_thisEpoch > epochStart) {
            marathonHermesPerEpoch[currentEpoch] = marathonLocker.currentStrategy();

            epochStart = _thisEpoch;

            unchecked {
                currentEpoch++;
            }
        }
    }
}