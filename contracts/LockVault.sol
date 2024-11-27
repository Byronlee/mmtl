// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVault {
    struct Deposit {
        uint256 amount;
        uint256 lockDate;
        uint256 unlockDate;
    }

    // 用户地址 => Token 地址 => 存款条目数组
    mapping(address => mapping(address => Deposit[])) public userDeposits;

    // 常量定义，锁定时间为10年
    uint256 public constant LOCK_DURATION = 10 * 365 days;

    // 事件定义
    event Transfer(address indexed from, address indexed to, uint256 value);
    event onDeposit(address indexed token, address indexed user, uint256 amount, uint256 lockDate, uint256 unlockDate);
    event onWithdraw(address indexed token, address indexed user, uint256 amount);

    // 存款功能
    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        // 检查并接收 Token
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 actualAmount = balanceAfter - balanceBefore;
        require(actualAmount > 0, "No tokens received");

        // 创建新的存款条目
        Deposit memory newDeposit = Deposit({
            amount: actualAmount,
            lockDate: block.timestamp,
            unlockDate: block.timestamp + LOCK_DURATION
        });

        userDeposits[msg.sender][token].push(newDeposit);

        emit Transfer(msg.sender, address(this), actualAmount);
        emit onDeposit(token, msg.sender, actualAmount, newDeposit.lockDate, newDeposit.unlockDate);
    }

    // 提款功能
    function withdraw(address token) external {
        Deposit[] storage deposits = userDeposits[msg.sender][token];
        uint256 totalWithdrawAmount = 0;

        for (uint256 i = 0; i < deposits.length; i++) {
            if (block.timestamp >= deposits[i].unlockDate && deposits[i].amount > 0) {
                totalWithdrawAmount += deposits[i].amount;
                deposits[i].amount = 0; // 标记为已提取
            }
        }

        require(totalWithdrawAmount > 0, "No unlocked tokens to withdraw");

        require(IERC20(token).transfer(msg.sender, totalWithdrawAmount), "Token transfer failed");
        emit onWithdraw(token, msg.sender, totalWithdrawAmount);
    }

    // 查询用户的存款条目
    function getDeposits(address user, address token) external view returns (Deposit[] memory) {
        return userDeposits[user][token];
    }
}
