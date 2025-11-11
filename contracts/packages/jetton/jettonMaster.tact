import "./JettonWallet";
import "../../messages";

message JettonMint {
    origin: Address;
    receiver: Address;
    amount: Int;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}


trait JettonMaster {
    totalSupply: Int;
    mintable: Bool;
    owner: Address;
    jettonContent: Cell;
    walletCode: Cell;

    //********************************************//
    //                  Messages                  //
    //********************************************//

    receive(msg: SetWalletCode) {
        require(sender() == self.owner, "JettonMaster: Sender is not a Jetton owner");
        self.walletCode = msg.code;
    } {}

    receive(msg: JettonBurnNotification) {
        self.burnNotificationValidate(msg);
        self.burnNotification( msg);
    }

    receive(msg: JettonMint) {
        let ctx: Context = context();
        self.mintValidate();
        self.mint(msg);
    }

    //********************************************//
    //             Internal functions             //
    //********************************************//

    abstract inline fun calculateJettonWalletInit(ownerAddress: Address): StateInit;

    virtual inline fun mintValidate() {
        require(sender() == self.owner, "JettonMaster: Sender is not a Jetton owner");
        require(self.mintable, "JettonMaster: Jetton is not mintable");
    }

    virtual inline fun mint(msg: JettonMint) {
        let initCode: StateInit = self.calculateJettonWalletInit(msg.receiver);
        self.totalSupply += msg.amount;
        send(SendParameters {
            to: contractAddress(initCode),
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: JettonInternalTransfer {
                queryId: 0,
                amount: msg.amount,
                responseDestination: msg.origin,
                from: myAddress(),
                forwardTonAmount: msg.forwardTonAmount,
                forwardPayload: msg.forwardPayload,
            }.toCell(),
            code: initCode.code,
            data: initCode.data,
        });
    }

    virtual inline fun burnNotificationValidate(msg: JettonBurnNotification) {
        let initCode: StateInit = self.calculateJettonWalletInit(msg.sender);
        require(sender() == contractAddress(initCode), "Sender is not a Jetton wallet");
    }

    inline fun burnNotification(msg: JettonBurnNotification) {
        self.totalSupply -= msg.amount;
        if (msg.responseDestination != newAddress(0, 0)) {
            send(SendParameters {
                to: msg.responseDestination,
                value: 0,
                bounce: false,
                mode: SendRemainingValue + SendIgnoreErrors,
            });
        }
    }

    //*********************************//
    //             Getters             //
    //*********************************//

    get fun get_jetton_data(): JettonData {
        return JettonData {
            totalSupply: self.totalSupply,
            mintable: self.mintable,
            adminAddress: self.owner,
            jettonContent: self.jettonContent,
            jettonWalletCode: self.calculateJettonWalletInit(myAddress()).code,
        };
    }

    get fun get_wallet_address(ownerAddress: Address): Address {
        let initCode: StateInit = self.calculateJettonWalletInit(ownerAddress);
        return contractAddress(initCode);
    }
}
