package com.leshun.hwinf;

import android.content.Context;
import android.util.Log;

import dalvik.system.DexClassLoader;

public class SerialPortAdapter {
    private static final String TAG  = "leshun_SerialAdapter";
    private SerialPortInf mInterface = null;

    /*初始化串口类设备接口
    * node：串口设备节点，例如 /dev/ttyHSL1
    * bit_rate：串口波特率*/
    public boolean init(Context ctx, String node, int bit_rate){
        if(mInterface == null){
            try{
                DexClassLoader cls_loader = ClassLoaderHelper.getCalssLoader(ctx);
                if(cls_loader == null)
                    return false;
                Class<?> myClass = cls_loader.loadClass("com.leshun.hwinf.SerialPortDevice");
                mInterface = (SerialPortInf) myClass.newInstance();
            } catch (Exception e){
                Log.e(TAG, "load class error: " + e);
                return false;
            }
        }
        return mInterface.init(node, bit_rate);
    }

    /*反初始化串口类设备接口*/
    public void deInit(){
        if(mInterface != null){
            mInterface.deInit();
            mInterface = null;
        }
    }

    /*开始读取串口类设备接口
     * 参数为回调接口，当串口有数据返回或者发生错误时，会调用回调接口 */
    public boolean startRead(HWDataCallBack cb){
        if(cb == null){
            Log.w(TAG, "startRead need HWDataCallBack!");
            return  false;
        }
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.startRead(cb);
    }

    /*停止读取串口接口*/
    public void stopRead(){
        if(mInterface != null)
            mInterface.stopRead();
    }

    /*往串口发送数据接口
    * data：待发送数据缓存区
    * len：待发送数据长度*/
    public boolean write(byte[] data, int len){
        if(data == null){
            Log.w(TAG, "write data is null!");
            return  false;
        }
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.writeData(data, len);
    }
}
