import "@stdlib/deploy";
import "../jettonWallet";

contract LLLJettonWallet with JettonWallet, Deploy {
    balance: Int as coins;
    owner: Address;
    jettonMaster: Address;

    init(jettonMaster: Address, owner: Address) {
        self.jettonMaster = jettonMaster;
        self.owner = owner;
        self.balance = 0;
    }
    override inline fun calculateJettonWalletInit(ownerAddress: Address): StateInit {
        return initOf LLLJettonWallet(self.jettonMaster,ownerAddress );
    }
}


