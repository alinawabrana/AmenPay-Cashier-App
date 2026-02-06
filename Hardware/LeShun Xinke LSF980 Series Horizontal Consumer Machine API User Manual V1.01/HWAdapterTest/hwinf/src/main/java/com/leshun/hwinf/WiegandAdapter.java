package com.leshun.hwinf;

import android.content.Context;
import android.util.Log;

import dalvik.system.DexClassLoader;

public class WiegandAdapter {
    private static final String TAG  = "leshun_WiegandAdapter";
    private WiegandInf mInterface = null;
    private static WiegandAdapter mInstance = null;

    private WiegandAdapter(){
    }

    /*获取韦根设备实例接口
     * 韦根设备采用单例模式，防止多线程读取韦根设备产生困扰*/
    public static WiegandAdapter getInstance(){
        if(mInstance == null)
            mInstance = new WiegandAdapter();
        return mInstance;
    }

    /*初始化韦根设备接口*/
    public boolean init(Context ctx){
        if(mInterface == null){
            try{
                DexClassLoader cls_loader = ClassLoaderHelper.getCalssLoader(ctx);
                if(cls_loader == null)
                    return false;
                Class<?> myClass = cls_loader.loadClass("com.leshun.hwinf.WiegandDevice");
                mInterface = (WiegandInf) myClass.newInstance();
            } catch (Exception e){
                Log.e(TAG, "load class error: " + e);
                return false;
            }
        }
        return mInterface.init();
    }

    /*反初始化韦根设备接口*/
    public void deInit(){
        if(mInterface != null){
            mInterface.deInit();
            mInterface = null;
        }
    }

    /*开始读取韦根设备接口
     * 参数为回调接口，当韦根设备有数据返回或者发生错误时，会调用回调接口 */
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

    /*停止读取韦根设备接口*/
    public void stopRead(){
        if(mInterface != null)
            mInterface.stopRead();
    }

    /*往韦根设备写入数据接口
    * data：待写入数据缓存
    * len：待写入数据长度，目前只支持24 or 32 bytes，对应26bit or 34bit*/
    public boolean write(byte[] data, int len){
        if(data == null){
            Log.w(TAG, "write data is null!");
            return  false;
        }
        if((len != 24) && (len != 32)){
            Log.w(TAG, "data len error, only 24 or 32 bytes allowed!");
            return false;
        }
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.write(data, len);
    }
}
