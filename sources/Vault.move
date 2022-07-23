module Vault::Escrow {
    use AptosFramework::Coin;
    use std::error;
    use aptos_std::event;
    use Std::Signer;

    const ECOIN_NOT_REGISTERED: u64 = 1;
    const EVAULT_ALREADY_MOVED: u64 = 2;
    const USER_NOT_DEPOSITED: u64 = 3;
    const BALANCE_NOT_ENOUGHT: u64 = 4;
    const ESCROW_PAUSED: u64 = 5;
    const INVALIED_ADMIN: u64 = 6;

    struct VaultCoin {}

    struct Escrow has key {
        vault: Coin::Coin<VaultCoin>,
        paused: bool
    }

    struct UserInfo has key {
        amount: u64,
        message_change_events: event::EventHandle<MessageWithdrawDepositEvent>,
    }

    struct MessageWithdrawDepositEvent has drop, store {
        from_amount: string::String,
        to_amount: string::String,
    }

    public(script) fun init_escrow(admin: signer) {
        let addr = Signer::address_of(&admin);
        assert!(Coin::is_account_registered<VaultCoin>(addr), ECOIN_NOT_REGISTERED);
        assert!(!exists<Escrow>(addr), EVAULT_ALREADY_MOVED);
        let vault = Coin::zero<VaultCoin>();
        move_to(&admin, Escrow {
            vault,
            paused: false
        });
    }

    public(script) fun pause_escrow(admin: signer) acquires Escrow {
        let addr = Signer::address_of(&admin);
        assert!(exists<Escrow>(addr), INVALIED_ADMIN);

        let old_escrow = borrow_global_mut<Escrow>(addr);
        old_escrow.paused = true;
    }

    
    public(script) fun pause_escrow(admin: signer) acquires Escrow {
        let addr = Signer::address_of(&admin);
        assert!(exists<Escrow>(addr), INVALIED_ADMIN);

        let old_escrow = borrow_global_mut<Escrow>(addr);
        old_escrow.paused = false;
    }

    public(script) fun deposit(user: signer, amount: u64, escrow_account: address) acquires Escrow {
        assert!(!*&borrow_global<Escrow>(escrow_account).paused, ESCROW_PAUSED);

        let addr = Signer::address_of(&user);
        assert!(Coin::is_account_registered<VaultCoin>(addr), ECOIN_NOT_REGISTERED);
        if (!exists<UserInfo>(addr)) {
            move_to(&user, UserInfo {
                amount: (copy amount)
            });
            event::emit_event(&mut old_info.message_change_events, MessageWithdrawDepositEvent {
                from_amount: 0,
                to_amount: copy amount,
            });
        } else {
            let old_info = borrow_global_mut<UserInfo>(addr);
            let from_amount = *&old_info.amount;
            event::emit_event(&mut old_info.message_change_events, MessageWithdrawDepositEvent {
                from_amount,
                to_amount: from_amount + (copy amount),
            });
            old_info.amount = old_info.amount + (copy amount);
        };
        let coin = Coin::withdraw<VaultCoin>(&user, amount);
        let escrow = borrow_global_mut<Escrow>(escrow_account);
        Coin::merge<VaultCoin>(&mut escrow.vault, coin);
    }

    public(script) fun withdraw(user: signer, amount: u64, escrow_account: address) acquires Escrow {
        assert!(!*&borrow_global<Escrow>(escrow_account).paused, ESCROW_PAUSED);

        let addr = Signer::address_of(&user);
        assert!(Coin::is_account_registered<VaultCoin>(addr), ECOIN_NOT_REGISTERED);
        assert!(exists<UserInfo>(addr), USER_NOT_DEPOSITED);

        let current_info = borrow_global_mut<UserInfo>(addr);
        let current_amount = *&current_info.amount;
        assert!(current_amount >= amount, BALANCE_NOT_ENOUGHT);

        event::emit_event(&mut current_info.message_change_events, MessageWithdrawDepositEvent {
            from_amount: current_amount,
            to_amount: current_amount - (copy amount),
        });
        current_info.amount = current_info.amount - (copy amount);

        let escrow = borrow_global_mut<Escrow>(escrow_account);
        let coins = Coin::extract<VaultCoin>(&mut escrow.vault, amount);
        Coin::deposit<VaultCoin>(addr, coins);
    } 
}