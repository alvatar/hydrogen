// TODO: Checks

contract;

use std::{
    address::Address,
    assert::assert,
    chain::auth::{AuthError, msg_sender},
    context::call_frames::{contract_id, msg_asset_id},
    context::msg_amount,
    contract_id::ContractId,
    identity::Identity,
    result::*,
    revert::{require, revert},
    storage::StorageMap,
    token::*,
    u128::U128,
};



enum Error {
    InsufficientFunds: (),
}

storage {
    asset_id_1: ContractId = ContractId {
        value: 0x0000000000000000000000000000000000000000000000000000000000000000,
    },
    
    asset_amount_1: u64 = 0,
    
    asset_id_2: ContractId = ContractId {
        value: 0x0000000000000000000000000000000000000000000000000000000000000000,
    },
    
    asset_amount_2: u64 = 0,
    
    providers: StorageMap<(Address, ContractId), u64> = StorageMap {},
    
    k: U128 = ~U128::new(),
}

abi HydrogenSwap {
    #[storage(write)]fn constructor(asset_id_1: ContractId, asset_id_2: ContractId);
    #[storage(read, write)]fn provide(amount_1: u64, amount_2: u64);
    #[storage(read,write)]fn swap1();
}

impl HydrogenSwap for Contract {
    #[storage(write)]fn constructor(asset_id_1: ContractId, asset_id_2: ContractId) {
        storage.asset_id_1 = asset_id_1;
        storage.asset_id_2 = asset_id_2;
    }

    #[storage(read, write)] fn provide(amount_1: u64, amount_2: u64) {
        require(msg_amount() > 0, Error::InsufficientFunds);

        // TODO: check that the amounts are correct
        storage.k = ~U128::from(0, amount_1) * ~U128::from(0, amount_2);
        storage.asset_amount_1 += storage.asset_amount_1 + amount_1;
        storage.asset_amount_2 += storage.asset_amount_2 + amount_2;
        
        let sender = get_msg_sender_address_or_panic();        
        let provider_amount_1 = storage.providers.get((sender, storage.asset_id_1)) + amount_1;
        storage.providers.insert((sender, storage.asset_id_1), provider_amount_1);
        let provider_amount_2 = storage.providers.get((sender, storage.asset_id_2)) + amount_2;
        storage.providers.insert((sender, storage.asset_id_2), provider_amount_2);

        // TODO transfer FROM sender
        // force_transfer_to_contract(amount_1, storage.asset_id_1, contract_id());
        // This needs to be done as two separate "provide" calls, tied together with a script
    }

    #[storage(read, write)] fn swap1() {
        let amount_1 = msg_amount();    
        let amount_2 = compute_asset2_amount_given_asset1(amount_1);

        storage.asset_amount_1 += storage.asset_amount_1 + amount_1;
        storage.asset_amount_2 -= storage.asset_amount_2 + amount_2;

        // Transfer to sender
        let address = get_msg_sender_address_or_panic();
        transfer_to_output(amount_2, storage.asset_id_2, address);
    }

}

#[storage(read)] fn compute_asset2_amount_given_asset1(amount: u64) -> u64 {
    let after1 = storage.asset_amount_1 + amount;
    let after2_u128 = storage.k / ~U128::from(0, after1);
    let after2_wrapped = after2_u128.as_u64();
    let after2 = match after2_wrapped {
        Result::Ok(inner_value) => inner_value, _ => revert(0), 
    };
    let asset_amount_2 = storage.asset_amount_2 - after2;
    asset_amount_2
}

/// Return the sender as an Address or panic
pub fn get_msg_sender_address_or_panic() -> Address {
    let sender: Result<Identity, AuthError> = msg_sender();
    if let Identity::Address(address) = sender.unwrap() {
       address
    } else {
       revert(0);
    }
}