package com.leshun.hwinf;

public interface HWDataCallBack {
    /*数据回调接口
    * data：读取到的字节数据
    * len：数据长度*/
    void onDataReceived(byte[] data, int len);
    /*错误回调接口
     * msg：错误描述信息*/
    void onError(String msg);
}
