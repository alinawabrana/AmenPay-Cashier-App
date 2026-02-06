package com.leshun.hwinf;

public abstract class NFCInf {
    public enum NFC_CARD_TYPE {
        CARD_TYPE_AUTO(1),
        CARD_TYPE_Mifare(2),
        CARD_TYPE_PlusCPU(3),
        CARD_TYPE_CPU(4);
        private int mValue;
        private NFC_CARD_TYPE(int val) {
            this.mValue = val;
        }
        public int getValue() {
            return this.mValue;
        }
    }
    public abstract boolean init(int type);
    public abstract void deInit();
    public abstract boolean startRead(HWDataCallBack cb);
    public abstract boolean startRead(HWDataCallBack cb, boolean bsingle);
    public abstract void stopRead();
    public abstract int readBlock(int block_id, byte[] auth_keyA, byte[] auth_keyB, byte[] buffer_rx);
    public abstract int writeBlock(int block_id, byte[] auth_keyA, byte[] auth_keyB, byte[] buffer_tx);
    public abstract int sendAPDU(byte[] cmd, int cmd_len, byte[] buffer_rx);
    public abstract int getATS(byte[] buffer_rx);
}
