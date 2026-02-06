package com.leshun.hwinf;

import android.content.Context;
import android.util.Log;

import dalvik.system.DexClassLoader;

public class NFCAdapter {
    private static final String TAG  = "leshun_NFCAdapter";
    private NFCInf mInterface = null;
    private static NFCAdapter mInstance = null;

    private NFCAdapter(){
    }

    /*获取NFC设备实例接口
    * NFC设备采用单例模式，防止多线程读取NFC设备产生困扰*/
    public static NFCAdapter getInstance(){
        if(mInstance == null)
            mInstance = new NFCAdapter();
        return mInstance;
    }

    /*初始化NFC设备接口
     * 参数为NFC卡类型，目前只支持 自动模式、Mifare卡、PlusCPU卡、CPU卡，默认请用Mifare卡 */
    public boolean init(Context ctx, NFCInf.NFC_CARD_TYPE type){
        if(mInterface == null){
            try{
                DexClassLoader cls_loader = ClassLoaderHelper.getCalssLoader(ctx);
                if(cls_loader == null)
                    return false;
                Class<?> myClass = cls_loader.loadClass("com.leshun.hwinf.NFCDevice");
                mInterface = (NFCInf) myClass.newInstance();
            } catch (Exception e){
                Log.e(TAG, "load class error: " + e);
                return false;
            }
        }
        return mInterface.init(type.getValue());
    }

    /*反初始化NFC设备接口*/
    public void deInit(){
        if(mInterface != null){
            mInterface.deInit();
            mInterface = null;
        }
    }

    /*开始读取NFC设备接口
     * 参数cb：回调接口，当NFC设备有IC卡接近或者发生错误时，会调用回调接口*/
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

    /*开始读取NFC设备接口
     * 参数cb：回调接口，当NFC设备有IC卡接近或者发生错误时，会调用回调接口
     * 参数 bsingle： 同一张卡，是否只上报一次（除非抬起过）*/
    public boolean startRead(HWDataCallBack cb, boolean bsingle){
        if(cb == null){
            Log.w(TAG, "startRead need HWDataCallBack!");
            return  false;
        }
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.startRead(cb, bsingle);
    }

    /*停止读取NFC设备接口*/
    public void stopRead(){
        if(mInterface != null)
            mInterface.stopRead();
    }

    /*读取指定区块数据，应当在startRead接口设定的回调函数里（收到卡号即有卡接近时）调用，秘钥A、B二选一传入
    * 参数block_id: 待读取的区块ID，以Mifare S50卡为例，范围0 - 63，共16个扇区，每个扇区4个区块，每个区块16字节；每个扇区最后一个区块（第3、7、11......）存储秘钥相关
    * 参数auth_keyA: 秘钥A， 6个字节或16个字节（PlusCPU SL3），可为NULL
    * 参数auth_keyB: 秘钥B， 6个字节或16个字节（PlusCPU SL3），可为NULL
    * 参数buffer_rx: 读取到的数据缓存区，长度为一个区块大小，16字节
    * 返回值：读取到的数据长度；-1 表示秘钥错误；-2表示其他错误*/
    public int readBlock(int block_id, byte[] auth_keyA, byte[] auth_keyB, byte[] buffer_rx){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return -2;
        }
        return mInterface.readBlock(block_id, auth_keyA, auth_keyB, buffer_rx);
    }

    /*写入指定区块数据，应当在startRead接口设定的回调函数里（收到卡号即有卡接近时）调用，秘钥A、B二选一传入
     * 参数block_id: 待写入的区块ID，以Mifare S50卡为例，范围0 - 63，共16个扇区，每个扇区4个区块，每个区块16字节；每个扇区最后一个区块（第3、7、11......）存储秘钥相关
     * 参数auth_keyA: 秘钥A， 6个字节或16个字节（PlusCPU SL3），可为NULL
     * 参数auth_keyB: 秘钥B， 6个字节或16个字节（PlusCPU SL3），可为NULL
     * 参数buffer_tx: 待写入的数据缓存区，长度为一个区块大小，16字节
     * 返回值：0 表示成功；-1 表示秘钥错误；-2表示其他错误*/
    public int writeBlock(int block_id, byte[] auth_keyA, byte[] auth_keyB, byte[] buffer_tx){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return -2;
        }
        return mInterface.writeBlock(block_id, auth_keyA, auth_keyB, buffer_tx);
    }

    /*CPU卡发送APDU包
     * 参数cmd:       APDU命令数据
     * 参数cmd_len:   cmd的长度
     * 参数buffer_rx: 返回的数据缓存区，缓存长度应不小于该命令返回的数据长度，否则会丢失数据
     * 返回值：APDU返回的数据长度；负数表示错误*/
    public int sendAPDU(byte[] cmd, int cmd_len, byte[] buffer_rx){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return -2;
        }
        return mInterface.sendAPDU(cmd, cmd_len, buffer_rx);
    }

    /*CPU卡获取ATS（answer to select）
     * 参数buffer_rx: 返回的数据缓存区，CPU卡一般为16Byte，Plus CPU卡一般为12Byte
     * 返回值：ATS的数据长度；负数表示错误*/
    public int getATS(byte[] buffer_rx){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return -2;
        }
        return mInterface.getATS(buffer_rx);
    }
}
