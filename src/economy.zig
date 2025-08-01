/// This file contains all game economy source code. (Buying, selling, trading, etc.)
const std = @import("std");

pub const Address = [16]u8;

pub const Transaction = struct {
    tx_id: usize,
    sender: Address,
    recipient: Address,
    timestamp: i64,
    amount: u64,
};

// System for tracking and managing transactions. This does not have anything to do with updating balances.
// All this system is designed to do is track and handle transaction creation. Balances are handled with wallets.
pub const TransactionSystem = struct {
    next_id: usize = 0,
    allocator: std.mem.Allocator,
    records: std.ArrayList(Transaction),
    pending: std.AutoHashMap(usize, Transaction),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) TransactionSystem {
        return .{
            .allocator = allocator,
            .records = std.ArrayList(Transaction).init(allocator),
            .pending = std.AutoHashMap(usize, Transaction).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *TransactionSystem) void {
        self.records.deinit();
        self.pending.deinit();
    }

    pub fn newTransaction(self: *TransactionSystem, sender: Address, recipient: Address, amount: u64) !Transaction {
        self.mutex.lock();
        defer self.mutex.unlock();

        const timestamp = std.time.timestamp();
        const tx_id = self.next_id;
        const tx = Transaction{
            .tx_id = tx_id,
            .sender = sender,
            .recipient = recipient,
            .timestamp = timestamp,
            .amount = amount,
        };
        try self.pending.put(tx_id, tx);
        self.next_id += 1;
        return tx;
    }

    pub fn approveTransaction(self: *TransactionSystem, tx_id: u64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const tx = self.pending.fetchRemove(tx_id) orelse return error.NoPendingTransaction;
        try self.records.append(tx.value);
    }

    pub fn rejectTransaction(self: *TransactionSystem, tx_id: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.pending.remove(tx_id);
    }
};

pub const Wallet = struct {
    address: Address,
    balance: u64,
};

pub const WalletSystem = struct {
    allocator: std.mem.Allocator,
    wallets: std.AutoHashMap(Address, *Wallet),

    pub fn init(allocator: std.mem.Allocator) WalletSystem {
        return .{
            .allocator = allocator,
            .wallets = std.AutoHashMap(Address, *Wallet).init(allocator),
        };
    }

    pub fn deinit(self: *WalletSystem) void {
        var iter = self.wallets.iterator();
        while (iter.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.wallets.deinit();
    }

    pub fn newWallet(self: *WalletSystem) !Address {
        var addr: Address = undefined;
        std.crypto.random.bytes(addr[0..]);

        while (self.wallets.contains(addr)) {
            std.crypto.random.bytes(addr[0..]);
        }

        const wallet = try self.allocator.create(Wallet);
        wallet.* = .{ .address = addr, .balance = 0 };

        try self.wallets.put(addr, wallet);
        return addr;
    }

    pub fn setBalance(self: *WalletSystem, address: Address, amount: u64) !void {
        const wallet = self.wallets.get(address) orelse return error.UnmanagedWalletAddress;
        wallet.balance = amount;
    }

    pub fn getBalance(self: *WalletSystem, address: Address) !u64 {
        const wallet = self.wallets.get(address) orelse return error.UnmanagedWalletAddress;
        return wallet.balance;
    }

    pub fn processTransaction(self: *WalletSystem, tx: Transaction, tx_system: *TransactionSystem) !void {
        const sender = self.wallets.get(tx.sender) orelse {
            tx_system.rejectTransaction(tx.tx_id);
            return error.UnmanagedWalletAddress;
        };

        const recipient = self.wallets.get(tx.recipient) orelse {
            tx_system.rejectTransaction(tx.tx_id);
            return error.UnmanagedWalletAddress;
        };

        if (sender.balance < tx.amount) {
            tx_system.rejectTransaction(tx.tx_id);
            return error.InsufficientBalance;
        }

        try tx_system.approveTransaction(tx.tx_id);

        sender.balance -= tx.amount;
        recipient.balance += tx.amount;
    }
};

pub const ProductCategoryFlags = enum(u32) {
    none = 0,
    ingredient = 1,
    equipment = 1 << 1,
    consumables = 1 << 2,
    merchandise = 1 << 3,
    packaging = 1 << 4,
};

pub const ProductExpiration = union(enum) {
    none,
    timestamp: i64,
};

pub const Product = struct {
    id: u32,
    name: []const u8,
    price: u64,
    brand: []const u8,
    description: []const u8,
    category_mask: u32,
    expiration: ProductExpiration,
};

pub const PriceVec = @Vector(2, u64); // high,low

pub const MarketSystem = struct {
    allocator: std.mem.Allocator,
    rw_lock: std.Thread.RwLock,

    products: std.ArrayList(Product),
    prices: std.ArrayList(PriceVec),

    pub fn init(allocator: std.mem.Allocator) !*MarketSystem {
        const self = try allocator.create(MarketSystem);
        self.* = .{
            .allocator = allocator,
            .rw_lock = .{},
            .products = std.ArrayList(Product).init(allocator),
            .prices = std.ArrayList(PriceVec).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *MarketSystem) void {
        self.products.deinit();
        self.prices.deinit();
        self.allocator.destroy(self);
    }

    /// Adds a new product to the market and sets its initial price.
    /// The product's ID will be its index in the products array.
    pub fn addProduct(self: *MarketSystem, name: []const u8, brand: []const u8, description: []const u8, category_mask: u32, expiration: ProductExpiration, initial_price: PriceVec) !void {
        self.rw_lock.lock();
        defer self.rw_lock.unlock();

        const product_id: u32 = @intCast(self.products.items.len);
        const new_product = Product{
            .id = product_id,
            .name = name,
            .price = @divFloor(initial_price[0] + initial_price[1], 2),
            .brand = brand,
            .description = description,
            .category_mask = category_mask,
            .expiration = expiration,
        };

        try self.products.append(new_product);
        try self.prices.append(initial_price);
    }

    /// Updates the price of a product using its ID.
    pub fn updatePrice(self: *MarketSystem, product_id: u32, new_price: PriceVec) !void {
        self.rw_lock.lock();
        defer self.rw_lock.unlock();

        if (product_id >= self.prices.items.len) {
            return error.ProductNotFound;
        }
        self.prices.items[product_id] = new_price;
    }

    /// Retrieves the price of a product by its ID.
    pub fn getPrice(self: *MarketSystem, product_id: u32) !PriceVec {
        self.rw_lock.lockShared();
        defer self.rw_lock.unlockShared();

        if (product_id >= self.prices.items.len) {
            return error.ProductNotFound;
        }
        return self.prices.items[product_id];
    }
};
// =============================================
//  ######## ########  ######  ########  ######
//     ##    ##       ##    ##    ##    ##    ##
//     ##    ##       ##          ##    ##
//     ##    ######    ######     ##     ######
//     ##    ##             ##    ##          ##
//     ##    ##       ##    ##    ##    ##    ##
//     ##    ########  ######     ##     ######
// =============================================
//
const testing = std.testing;
const testing_allocator = testing.allocator;

// ===================================
//  TransactionSystem Tests
// ===================================
test "TransactionSystem: init and deinit" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();
    try testing.expectEqual(0, tx_system.records.items.len);
    try testing.expectEqual(0, tx_system.pending.count());
}

test "TransactionSystem: newTransaction" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();

    const sender_addr: Address = [_]u8{1} ** 16;
    const recipient_addr: Address = [_]u8{2} ** 16;

    const tx = try tx_system.newTransaction(sender_addr, recipient_addr, 100);
    try testing.expectEqual(@as(usize, 0), tx.tx_id);
    try testing.expectEqual(@as(u64, 100), tx.amount);
    try testing.expectEqual(1, tx_system.pending.count());
    try testing.expect(tx_system.pending.contains(0));
}

test "TransactionSystem: approveTransaction" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();

    const sender_addr: Address = [_]u8{1} ** 16;
    const recipient_addr: Address = [_]u8{2} ** 16;

    const tx = try tx_system.newTransaction(sender_addr, recipient_addr, 100);
    try tx_system.approveTransaction(tx.tx_id);

    try testing.expectEqual(0, tx_system.pending.count());
    try testing.expectEqual(1, tx_system.records.items.len);
    try testing.expectEqual(tx.tx_id, tx_system.records.items[0].tx_id);
}

test "TransactionSystem: approve non-existent transaction" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();
    try testing.expectError(error.NoPendingTransaction, tx_system.approveTransaction(999));
}

test "TransactionSystem: rejectTransaction" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();

    const sender_addr: Address = [_]u8{1} ** 16;
    const recipient_addr: Address = [_]u8{2} ** 16;
    const tx = try tx_system.newTransaction(sender_addr, recipient_addr, 100);

    tx_system.rejectTransaction(tx.tx_id);
    try testing.expectEqual(0, tx_system.pending.count());
    try testing.expectEqual(0, tx_system.records.items.len);
}

// ===================================
//  WalletSystem Tests
// ===================================
test "WalletSystem: init and deinit" {
    var wallet_system = WalletSystem.init(testing_allocator);
    defer wallet_system.deinit();
    try testing.expectEqual(0, wallet_system.wallets.count());
}

test "WalletSystem: newWallet" {
    var wallet_system = WalletSystem.init(testing_allocator);
    defer wallet_system.deinit();

    const addr1 = try wallet_system.newWallet();
    const balance1 = try wallet_system.getBalance(addr1);
    try testing.expectEqual(@as(u64, 0), balance1);
    try testing.expectEqual(1, wallet_system.wallets.count());

    const addr2 = try wallet_system.newWallet();
    try testing.expect(std.mem.eql(u8, &addr1, &addr2) == false);
    try testing.expectEqual(2, wallet_system.wallets.count());
}

test "WalletSystem: getBalance" {
    var wallet_system = WalletSystem.init(testing_allocator);
    defer wallet_system.deinit();

    const addr = try wallet_system.newWallet();
    try wallet_system.setBalance(addr, 500);

    const balance = try wallet_system.getBalance(addr);
    try testing.expectEqual(@as(u64, 500), balance);
}

test "WalletSystem: getBalance of unmanaged wallet" {
    var wallet_system = WalletSystem.init(testing_allocator);
    defer wallet_system.deinit();
    const fake_addr: Address = [_]u8{9} ** 16;
    try testing.expectError(error.UnmanagedWalletAddress, wallet_system.getBalance(fake_addr));
}

// ===================================
//  Integration Tests (WalletSystem + TransactionSystem)
// ===================================
test "WalletSystem: processTransaction successful" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();

    var wallet_system = WalletSystem.init(testing_allocator);
    defer wallet_system.deinit();

    const sender_addr = try wallet_system.newWallet();
    try wallet_system.setBalance(sender_addr, 1000);

    const recipient_addr = try wallet_system.newWallet();
    try wallet_system.setBalance(recipient_addr, 500);

    const tx = try tx_system.newTransaction(sender_addr, recipient_addr, 250);
    try wallet_system.processTransaction(tx, &tx_system);

    // Check balances
    const sender_balance = try wallet_system.getBalance(sender_addr);
    try testing.expectEqual(@as(u64, 750), sender_balance);
    const recipient_balance = try wallet_system.getBalance(recipient_addr);
    try testing.expectEqual(@as(u64, 750), recipient_balance);

    // Check transaction status
    try testing.expectEqual(0, tx_system.pending.count());
    try testing.expectEqual(1, tx_system.records.items.len);
}

test "WalletSystem: processTransaction insufficient balance" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();

    var wallet_system = WalletSystem.init(testing_allocator);
    defer wallet_system.deinit();

    const sender_addr = try wallet_system.newWallet();
    try wallet_system.setBalance(sender_addr, 100); // Not enough balance

    const recipient_addr = try wallet_system.newWallet();
    try wallet_system.setBalance(recipient_addr, 500);

    const tx = try tx_system.newTransaction(sender_addr, recipient_addr, 250);
    const result = wallet_system.processTransaction(tx, &tx_system);

    try testing.expectError(error.InsufficientBalance, result);

    // Balances should not have changed
    const sender_balance = try wallet_system.getBalance(sender_addr);
    try testing.expectEqual(@as(u64, 100), sender_balance);
    const recipient_balance = try wallet_system.getBalance(recipient_addr);
    try testing.expectEqual(@as(u64, 500), recipient_balance);

    // Transaction should be rejected (removed from pending)
    try testing.expectEqual(0, tx_system.pending.count());
    try testing.expectEqual(0, tx_system.records.items.len);
}

test "WalletSystem: processTransaction with unmanaged sender" {
    var tx_system = TransactionSystem.init(testing_allocator);
    defer tx_system.deinit();

    var wallet_system = WalletSystem.init(testing_allocator);
    defer wallet_system.deinit();

    const fake_sender_addr: Address = [_]u8{8} ** 16;
    const recipient_addr = try wallet_system.newWallet();

    const tx = try tx_system.newTransaction(fake_sender_addr, recipient_addr, 100);
    const result = wallet_system.processTransaction(tx, &tx_system);

    try testing.expectError(error.UnmanagedWalletAddress, result);
    try testing.expectEqual(0, tx_system.pending.count());
}

// ===================================
//  MarketSystem Tests
// ===================================
test "MarketSystem: init and deinit" {
    var market = try MarketSystem.init(testing_allocator);
    defer market.deinit();
    try testing.expectEqual(0, market.products.items.len);
    try testing.expectEqual(0, market.prices.items.len);
}

test "MarketSystem: addProduct" {
    var market = try MarketSystem.init(testing_allocator);
    defer market.deinit();

    const price: PriceVec = .{ 10, 5 };
    try market.addProduct("Test Item", "Test Brand", "A test description", @intFromEnum(ProductCategoryFlags.consumables), .none, price);

    try testing.expectEqual(1, market.products.items.len);
    try testing.expectEqual(1, market.prices.items.len);

    const product = market.products.items[0];
    try testing.expectEqualStrings("Test Item", product.name);
    try testing.expectEqual(@as(u32, 0), product.id);

    const stored_price = market.prices.items[0];
    try testing.expectEqual(price, stored_price);
}

test "MarketSystem: getPrice and updatePrice" {
    var market = try MarketSystem.init(testing_allocator);
    defer market.deinit();

    const initial_price: PriceVec = .{ 10, 5 };
    try market.addProduct("Test Item", "Test Brand", "", @intFromEnum(ProductCategoryFlags.consumables), .none, initial_price);

    const fetched_price = try market.getPrice(0);
    try testing.expectEqual(initial_price, fetched_price);

    const new_price: PriceVec = .{ 12, 6 };
    try market.updatePrice(0, new_price);

    const updated_price = try market.getPrice(0);
    try testing.expectEqual(new_price, updated_price);
}

test "MarketSystem: get/update price for non-existent product" {
    var market = try MarketSystem.init(testing_allocator);
    defer market.deinit();

    try testing.expectError(error.ProductNotFound, market.getPrice(0));
    const new_price: PriceVec = .{ 1, 1 };
    try testing.expectError(error.ProductNotFound, market.updatePrice(0, new_price));
}
