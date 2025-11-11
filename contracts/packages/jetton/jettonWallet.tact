import "../../messages";

trait JettonWallet {
    balance: Int as coins;
    owner: Address;
    master: Address;
    
    virtual const gasConsumption: Int = ton("0.013");
    virtual const minTonsForStorage: Int = ton("0.019");

    //********************************************//
    //                  Messages                  //
    //********************************************//

    receive(msg: TokenTransfer) {
        let ctx: Context = context();
        require(msg.amount > 0, "JettonWallet: zero amount");
        require(self.balance >= msg.amount, "JettonWallet: Not enough jettons to transfer");
        self.balance -= msg.amount;
        self.transferValidate();
        self.transferEstimateRemainValue(ctx, msg);
        self.transferJetton(msg);
    }

    receive(msg: TokenBurn) {
        require(msg.amount > 0, "JettonWallet: zero amount");
        require(self.balance >= msg.amount, "JettonWallet: Not enough balance to burn tokens");
        self.balance -= msg.amount;
        self.burnValidate();
        self.burnTokens(msg);
    }

    receive(msg: TokenTransferInternal) {
        let ctx: Context = context();
        self.balance += msg.amount;
        require(self.balance >= 0, "JettonWallet: Not allow negative balance after internal transfer");
        self.internalTransferValidate(msg);
        let remain: Int = self.internalTransferEstimateRemainValue(ctx, msg);
        if (msg.forwardTonAmount > 0) {
            self.internalTransferNotification(msg);
        }
        self.internalTransferExcesses(msg, remain);
    }

    bounced(src: bounced<TokenTransferInternal>) {
        self.balance += src.amount;
    }

    bounced(src: bounced<TokenBurnNotification>) {
        self.balance += src.amount;
    }

    //********************************************//
    //             Internal functions             //
    //********************************************//

    abstract inline fun calculateJettonWalletInit(ownerAddress: Address): StateInit;

    virtual inline fun internalTransferValidate(msg: TokenTransferInternal) {
        if (sender() != self.jettonMaster) {
            let init: StateInit = self.calculateJettonWalletInit(msg.from);
            require(sender() == contractAddress(init), "JettonWallet: Only Jetton master or Jetton wallet can call this function");
        }
    }

    virtual inline fun internalTransferEstimateRemainValue(ctx: Context, msg: TokenTransferInternal): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - ctx.value;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        let remain: Int = ctx.value - (storageFee + self.gasConsumption);
        if (msg.forwardTonAmount > 0) {
            remain -= ctx.readForwardFee() + msg.forwardTonAmount;
        }
        return remain;
    }

    virtual inline fun internalTransferNotification(msg: TokenTransferInternal) {
        if (msg.forwardTonAmount > 0) {
            send(SendParameters {
                to: self.owner,
                value: msg.forwardTonAmount,
                mode: SendPayGasSeparately,
                bounce: false,
                body: TokenNotification {
                    queryId: msg.queryId,
                    amount: msg.amount,
                    from: msg.from,
                    forwardPayload: msg.forwardPayload,
                }.toCell(),
            });
        }
    }

    virtual inline fun internalTransferExcesses(msg: TokenTransferInternal, remain: Int) {
        if ((msg.responseDestination != newAddress(0, 0)) && remain > 0) {
            send(SendParameters {
                to: msg.responseDestination,
                value: remain,
                bounce: false,
                mode: SendIgnoreErrors,
                body: TokenExcesses {
                    queryId: msg.queryId,
                }.toCell(),
            });
        }
    }

    virtual inline fun burnValidate() {
        require(sender() == self.owner, "JettonWallet: Only owner can burn tokens");
    }

    virtual inline fun burnTokens(msg: TokenBurn) {
        send(SendParameters {
            to: self.jettonMaster,
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: TokenBurnNotification {
                queryId: msg.queryId,
                amount: msg.amount,
                sender: self.owner,
                responseDestination: msg.responseDestination,
            }.toCell(),
        });
    }

    virtual inline fun transferValidate() {
        require(sender() == self.owner, "Only owner can call this function");
    }

    virtual inline fun transferEstimateRemainValue(ctx: Context, msg: TokenTransfer) {
        let fwdCount: Int = 1;
        if (msg.forwardTonAmount > 0) {
            fwdCount = 2;
        }
        require(ctx.value > fwdCount * ctx.readForwardFee() + 2 * self.gasConsumption + self.minTonsForStorage, "Not enough funds to transfer");
    }

    virtual inline fun transferJetton(msg: TokenTransfer) {
        let init: StateInit = self.calculateJettonWalletInit(msg.destination);
        let receiver: Address = contractAddress(init);
        send(SendParameters {
            to: receiver,
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: TokenTransferInternal {
                queryId: msg.queryId,
                amount: msg.amount,
                responseDestination: msg.responseDestination,
                from: self.owner,
                forwardTonAmount: msg.forwardTonAmount,
                forwardPayload: msg.forwardPayload,
            }.toCell(),
            code: init.code,
            data: init.data,
        });
    }

    //*********************************//
    //             Getters             //
    //*********************************//

    get fun get_wallet_data(): JettonWalletData {
        return JettonWalletData {
            balance: self.balance,
            owner: self.owner,
            master: self.jettonMaster,
            code: self.calculateJettonWalletInit(self.owner).code,
        };
    }
}
