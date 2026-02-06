package test.leshun.hwadaptertest;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Message;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;
import android.support.v4.content.FileProvider;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import com.leshun.hwinf.*;
import com.printsdk.PrintSerializable;

import java.util.HashMap;
import java.util.Iterator;
import java.math.BigInteger;
import java.util.ArrayList;

public class MainActivity extends AppCompatActivity implements View.OnClickListener{
    private static final String TAG = "HardwareAdapterMain";
    private static final int  MSG_UPDATE_NFC = 1;
    private static final int  MSG_UPDATE_UART = 2;
    private static final int  MSG_UPDATE_SCANNER = 3;
    private static final int  MSG_LOOP_NFC_DETECT = 4;
    private static final int  MSG_UPDATE_SYSTEM_INFO = 5;
    private Button btn_nfc, btn_uart, btn_scanner, btn_printer, btn_brightness, btn_hide_nav, btn_show_nav, btn_reboot, btn_self_upadte;
    private TextView tx_nfc, tx_uart, tx_scanner, tx_printer, tx_brightness, tx_imei_val, tx_temp_val, tx_version;
    private boolean b_nfc_testing = false, b_uart_testing = false, b_scanner_testing = false, b_brightness_testing = false;
    private LedAdapter      m_led_device = null;
    private NFCAdapter      m_nfc_device = null;
    private SerialPortAdapter m_uart_device = null;
    private SerialPortAdapter m_scanner_device = null;
    private SystemAdapter   m_system_device = null;
    private UsbManager        mUsbManager = null;
    private PrintSerializable mPrinter = null;             //  打印机类
    private byte[]        data_send = {0x30, 0x31, 0x32};    //Uart的回环测试数据
    private static long           timestamp = 0L;
    private static boolean        bReading = false;

    //动态申请权限
    ArrayList<String> mPermissionsList;
    private final static int REQUEST_CODE =99;

    @SuppressLint("HandlerLeak")
    private Handler        handler = new Handler(){
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what){
                case MSG_UPDATE_NFC:
                    String result = msg.getData().getString("data");
                    Log.d(TAG, "read nfc id tooks: " + (System.currentTimeMillis() - timestamp));
                    tx_nfc.setText(result);
                    break;
                case MSG_LOOP_NFC_DETECT:
                    sendEmptyMessageDelayed(MSG_LOOP_NFC_DETECT, 500);    //循环检查是否需要寻卡
                    synchronized (MainActivity.this) {
                        if (bReading) {
                            break;        //如果已经在寻卡或者读写操作，不要再调用寻卡
                        }
                    }
                    timestamp = System.currentTimeMillis();
                    synchronized (MainActivity.this) {
                        bReading = true;   //标记正在寻卡
                    }
                    m_nfc_device.startRead(nfc_cb, false);   //是否防重复寻卡
                    tx_nfc.setText(R.string.nfc_testing);
                    break;
                case MSG_UPDATE_UART:
                    boolean uart_result = msg.getData().getBoolean("data");
                    tx_uart.setText(uart_result ? R.string.uart_test_success : R.string.uart_test_failed);
                    break;
                case MSG_UPDATE_SCANNER:
                    String scanner_result = msg.getData().getString("data");
                    tx_scanner.setText(scanner_result);
                case MSG_UPDATE_SYSTEM_INFO:
                    tx_imei_val.setText((m_system_device == null) ? "unknown" : m_system_device.getDeviceUniqueID());
                    tx_temp_val.setText((m_system_device == null) ? "unknown" : String.valueOf(m_system_device.getCPUTemp()));
                    break;
            }
        }
    };

    private HWDataCallBack nfc_cb = new HWDataCallBack() {
        @Override
        public void onDataReceived(byte[] bytes, int len) {
            Log.d(TAG, "data: " + bytesToHexString(bytes, len));
            /*因回调不在主线程，无法操作UI，采用Handler方式*/
            Message msg = new Message();
            msg.what = MSG_UPDATE_NFC;
            Bundle b = new Bundle();
            //16进制卡号转10进制字符串
            b.putString("data", new BigInteger(bytesToHexString(bytes, len), 16).toString());
            msg.setData(b);
            handler.sendMessage(msg);
            //--------------------------------------------------------------------------------------------------
            /*读取到Mifare S50/70以及Plus CPU卡SL1级别卡号（有卡接近），如果不需要读写指定区块，跳过下面代码*/
            /*byte[] buffer = new byte[16];
            int ret;
            long used_time = System.currentTimeMillis();
            byte   default_key = (byte)0xFF;
            //以下演示读取和写入区块20，这里使用默认秘钥（秘钥A和B二选一）；注意第3、7、11...区块是各扇区的秘钥区块，改写请谨慎
            //byte[] auth_keyA = {0x06,0x3B,0x2D,0x6E,0x70,0x1F};
            byte[] auth_keyA = {default_key,default_key,default_key,default_key,default_key,default_key};
            ret = m_nfc_device.readBlock(20, auth_keyA, null, buffer);
            if(ret > 0){
                used_time = System.currentTimeMillis() - used_time;
                Log.d(TAG, "read block tooks: " + used_time);
                buffer[15] = (byte) (buffer[15] + 1);
                used_time = System.currentTimeMillis();
                ret = m_nfc_device.writeBlock(20, auth_keyA, null, buffer);
                used_time = System.currentTimeMillis() - used_time;
                Log.d(TAG, "write block, tooks: " + used_time + ", ret: " + ret);
                buffer[15] = 0;
                used_time = System.currentTimeMillis();
                ret = m_nfc_device.readBlock(20, auth_keyA, null, buffer);
                used_time = System.currentTimeMillis() - used_time;
                if(ret > 0)
                    Log.d(TAG, "read block after write tooks: " + used_time);
                else
                    Log.w(TAG, "read block after write error.");
            }else if(ret == -1){
                Log.w(TAG, "auth_key error!");
            }*/

            //--------------------------------------------------------------------------------------------------
            //测试先错误后正确秘钥读写M1卡，错误秘钥调用后，startRead防撞卡失效，再次调用startRead可以读取到未抬起的M1卡
            /*byte[] buffer = new byte[16];
            int ret;
            byte   default_key = (byte)0xFF;
            byte[] auth_keyA_1 = {0x06,0x3B,0x2D,0x6E,0x70,0x1F};
            byte[] auth_keyA_2 = {default_key,default_key,default_key,default_key,default_key,default_key};
            if(test_index == 1) {
                ret = m_nfc_device.readBlock(20, auth_keyA_1, null, buffer);
                Log.d(TAG, "read block with error key, ret: " + ret);
            }
            else {
                ret = m_nfc_device.readBlock(20, auth_keyA_2, null, buffer);
                Log.d(TAG, "read block with correct key, ret: " + ret);
            }*/

            //--------------------------------------------------------------------------------------------------
            /*读取到Plus CPU SL3卡号（有卡接近），测试Plus CPU SL3的读写指定区块，如果不需要，跳过下面代码*/
            /*byte[] buffer = new byte[16];
            int ret;
            long used_time = System.currentTimeMillis();
            byte   default_key = (byte)0xFF;
            //以下演示读取和写入区块20，这里使用默认秘钥（Plus CPU卡，秘钥是16个字节）
            byte[] auth_keyA = {default_key,default_key,default_key,default_key,default_key,default_key,default_key,
                    default_key,default_key,default_key,default_key,default_key,default_key,default_key,default_key,default_key};
            ret = m_nfc_device.readBlock(20, auth_keyA, null, buffer);
            if(ret == 0){
                used_time = System.currentTimeMillis() - used_time;
                Log.d(TAG, "read block tooks: " + used_time);
                buffer[15] = (byte) (buffer[15] + 1);
                used_time = System.currentTimeMillis();
                ret = m_nfc_device.writeBlock(20, auth_keyA, null, buffer);
                used_time = System.currentTimeMillis() - used_time;
                Log.d(TAG, "write block, tooks: " + used_time + ", ret: " + ret);
                buffer[15] = 0;
                used_time = System.currentTimeMillis();
                ret = m_nfc_device.readBlock(20, auth_keyA, null, buffer);
                used_time = System.currentTimeMillis() - used_time;
                if(ret == 0)
                    Log.d(TAG, "read block after write tooks: " + used_time);
                else
                    Log.w(TAG, "read block after write error.");
            }else if(ret == -1){
                Log.w(TAG, "auth_key error!");
            }*/

            //--------------------------------------------------------------------------------------------------
            /*CPU卡发送APDU包*/
            /*byte[] cmd_1 = {0x00, (byte)0xA4, 0x00, 0x00, 0x02, 0x3F, 0x01};
            byte[] cmd_2 = {0x00, (byte)0x84, 0x00, 0x00, 0x04};
            byte[] cmd_3 = {0x04, (byte)0xB0, (byte)0x96, 0x00, 0x04, 0x13, 0x65, 0x2d, (byte)0xf9};
            byte[] cmd_ret = new byte[256];     //buffer大小要不小于此命令的返回数据，否则会数据丢失
            long time_sp = System.currentTimeMillis();
            int ret = m_nfc_device.sendAPDU(cmd_1, 7, cmd_ret);
            time_sp = System.currentTimeMillis() - time_sp;
            if(ret > 0)
                Log.d(TAG, "cmd1: " + time_sp + ", data: " + bytesToHexString(cmd_ret, ret));
            else
                Log.w(TAG, "cmd1 failed, ret : " + ret);

            if(ret > 0) {
                time_sp = System.currentTimeMillis();
                ret = m_nfc_device.sendAPDU(cmd_2, 5, cmd_ret);
                time_sp = System.currentTimeMillis() - time_sp;
                if (ret > 0)
                    Log.d(TAG, "cmd2: " + time_sp + ", data: " + bytesToHexString(cmd_ret, ret));
                else
                    Log.w(TAG, "cmd2 failed, ret : " + ret);
            }
            if(ret > 0) {
                time_sp = System.currentTimeMillis();
                ret = m_nfc_device.sendAPDU(cmd_3, 9, cmd_ret);
                time_sp = System.currentTimeMillis() - time_sp;
                if (ret > 0)
                    Log.d(TAG, "cmd3: " + time_sp + ", data: " + bytesToHexString(cmd_ret, ret));
                else
                    Log.w(TAG, "cmd3 failed, ret : " + ret);
            }*/

            //--------------------------------------------------------------------------------------------------
            /*CPU卡获取ATS*/
            /*byte[] ats_ret = new byte[16];
            int ats_len = m_nfc_device.getATS(ats_ret);
            if(ats_len > 0){
                Log.d(TAG, "getATS success, ret: "+ ats_len + ", data: " + bytesToHexString(ats_ret, ats_len));

            }else{
                Log.d(TAG, "getATS failed, ret: "+ ats_len);
            }*/

            //--------------------------------------------------------------------------------------------------
            synchronized (MainActivity.this) {
                bReading = false;    //已寻到卡并且读写操作结束，标记为未在寻卡
            }
        }

        @Override
        public void onError(String s) {
            Log.e(TAG, "nfc read error.");
            Message msg = new Message();
            msg.what = MSG_UPDATE_NFC;
            Bundle b = new Bundle();
            b.putString("data", "read error");
            msg.setData(b);
            handler.sendMessage(msg);
            handler.removeMessages(MSG_LOOP_NFC_DETECT);
            //如果出错，需停止寻卡并再次开始寻卡
            m_nfc_device.stopRead();
            synchronized (MainActivity.this) {
                bReading = false;
            }
            handler.sendEmptyMessageDelayed(MSG_LOOP_NFC_DETECT, 500);
        }
    };

    private String bytesToHexString(byte[] src, int len){
        StringBuilder stringBuilder = new StringBuilder("");
        if (src == null || len <= 0) {
            return null;
        }
        for (int i = 0; i < len; i++) {
            int v = src[i] & 0xFF;
            String hv = Integer.toHexString(v);
            if (hv.length() < 2) {
                stringBuilder.append(0);
            }
            stringBuilder.append(hv);
        }
        return stringBuilder.toString();
    }

    private UsbDevice findUsbPrinterDevice(){
        if(mUsbManager == null){
            Log.w(TAG, "usbManager is null.");
            return null;
        }
        HashMap<String, UsbDevice> devices = mUsbManager.getDeviceList();
        Iterator<UsbDevice> deviceIterator = devices.values().iterator();
        if (devices.size() > 0)
        {
            while( deviceIterator.hasNext() )
            {
                UsbDevice device = deviceIterator.next();
                UsbInterface usbInterface = device.getInterface(0);
                //match device type & vid,pid
                if( usbInterface.getEndpointCount() == 2)
                {
                    String name = device.getDeviceName();
                    int vid  = device.getVendorId();
                    int pid  = device.getProductId();
                    if(vid == 0x28E9 && pid == 0x0289){
                        Log.d(TAG, "match printer, name: " + name);
                        return device;
                    }else{
                        Log.d(TAG, "find devices, vid: " + vid + ", pid: " + pid + ", not match, ignore.");
                    }
                }
            }
        }
        return null;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        requestPermissions();
        init();
    }

    @SuppressLint("NewApi")
    private void requestPermissions() {
        mPermissionsList = new ArrayList<String>();
        checkPermission(Manifest.permission.READ_PHONE_STATE);
        checkPermission(Manifest.permission.READ_EXTERNAL_STORAGE);
        checkPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE);
        if(!mPermissionsList.isEmpty()){
            int size=mPermissionsList.size();
            String[] permissions = mPermissionsList.toArray(new String[size]);
            requestPermissions(permissions,REQUEST_CODE);
        }
    }

    @SuppressLint("NewApi")
    private void checkPermission(String permission) {
        if(checkSelfPermission(permission)
                != PackageManager.PERMISSION_GRANTED){
            mPermissionsList.add(permission);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,  String[] permissions,  int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if(requestCode==REQUEST_CODE){
            for(int i=0;i<permissions.length;i++){
                if(grantResults[i]==PackageManager.PERMISSION_DENIED){
                    new AlertDialog.Builder(this)
                            .setTitle(getString(R.string.permission_denied_title))
                            .setMessage(getString(R.string.permission_denied_msg))
                            .setPositiveButton(android.R.string.yes,new DialogInterface.OnClickListener(){
                                @Override
                                public void onClick(DialogInterface dialog, int which) {
                                    finish();
                                }
                            })
                            .setCancelable(false)
                            .show();
                }
            }
        }
    }

    private void init(){
        btn_nfc = (Button)findViewById(R.id.btn_nfc);
        btn_uart = (Button)findViewById(R.id.btn_uart);
        btn_scanner = (Button)findViewById(R.id.btn_scanner);
        btn_printer = (Button)findViewById(R.id.btn_printer);
        btn_brightness = (Button)findViewById(R.id.btn_brightness);
        btn_hide_nav = (Button)findViewById(R.id.btn_hide_nav);
        btn_show_nav = (Button)findViewById(R.id.btn_show_nav);
        btn_reboot = (Button)findViewById(R.id.btn_reboot);
        btn_self_upadte = (Button)findViewById(R.id.btn_self_update);

        btn_nfc.setOnClickListener(this);
        btn_uart.setOnClickListener(this);
        btn_scanner.setOnClickListener(this);
        btn_printer.setOnClickListener(this);
        btn_brightness.setOnClickListener(this);
        btn_hide_nav.setOnClickListener(this);
        btn_show_nav.setOnClickListener(this);
        btn_reboot.setOnClickListener(this);
        btn_self_upadte.setOnClickListener(this);

        tx_nfc = (TextView)findViewById(R.id.tx_nfc);
        tx_uart = (TextView)findViewById(R.id.tx_uart);
        tx_scanner = (TextView)findViewById(R.id.tx_scanner);
        tx_printer = (TextView)findViewById(R.id.tx_printer);
        tx_brightness = (TextView)findViewById(R.id.tx_brightness);
        tx_imei_val = (TextView)findViewById(R.id.tx_imei_val);
        tx_temp_val = (TextView)findViewById(R.id.tx_temp_val);
        tx_version = (TextView)findViewById(R.id.tx_version);

        /*初始化补光灯接口类*/
        m_led_device = new LedAdapter();
        if(!m_led_device.init(this)){
            Log.e(TAG, "init Led device error");
            m_led_device.deInit();
            m_led_device = null;
        }
        /*初始化NFC接口类，init参数为NFC卡类型，可选auto、mifare、PlusCPU、CPU，默认mifare*/
        m_nfc_device = NFCAdapter.getInstance();
        if(m_nfc_device != null){
            if(!m_nfc_device.init(this, NFCInf.NFC_CARD_TYPE.CARD_TYPE_Mifare)){
                Log.e(TAG, "init NFC device error");
                m_nfc_device.deInit();
                m_nfc_device = null;
            }
        }
        /*初始化串口接口类，这里init的参数只是示例，具体设备节点和波特率会随主板不同而可能变化*/
        m_uart_device = new SerialPortAdapter();
        if(!m_uart_device.init(this,"/dev/ttyHSL1", 115200)){
            Log.e(TAG, "init Uart device error");
            m_uart_device.deInit();
            m_uart_device = null;
        }

        //扫码头是串口设备，这里只创建对象，待开启扫码头时再初始化
        m_scanner_device = new SerialPortAdapter();

        /*初始化系统接口类
        * 需要添加READ_PHONE_STATE权限，6.0以上动态申请*/
        m_system_device = new SystemAdapter();
        if(!m_system_device.init(this)){
            Log.e(TAG, "init system device error");
            m_system_device.deInit();
            m_system_device = null;
        }

        //初始化打印机相关
        mUsbManager = (UsbManager)getSystemService(Context.USB_SERVICE);
        UsbDevice mUsbDevice = findUsbPrinterDevice();
        if(mUsbDevice != null) {
            mPrinter = new PrintSerializable();
            mPrinter.open(mUsbManager, mUsbDevice);
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if(m_led_device != null){
            m_led_device.deInit();
            m_led_device = null;
        }
        if(m_nfc_device != null){
            m_nfc_device.deInit();
            m_nfc_device = null;
        }
        if(m_uart_device != null){
            m_uart_device.deInit();
            m_uart_device = null;
        }
        m_scanner_device = null;
        if(m_system_device != null){
            m_system_device.deInit();
            m_system_device = null;
        }
        if(mPrinter != null){
            mPrinter.close();
            mPrinter = null;
        }
        mUsbManager = null;
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateUI();
        /*定时更新CPU温度等信息*/
        handler.sendEmptyMessageDelayed(MSG_UPDATE_SYSTEM_INFO, 3000);
    }

    @Override
    protected void onPause() {
        super.onPause();
        handler.removeMessages(MSG_UPDATE_SYSTEM_INFO);
        if(b_nfc_testing){
            handler.removeMessages(MSG_UPDATE_NFC);
            handler.removeMessages(MSG_LOOP_NFC_DETECT);
            m_nfc_device.stopRead();
            b_nfc_testing = false;
            synchronized (MainActivity.this) {
                bReading = false;
            }
        }
        if(b_uart_testing){
            m_uart_device.stopRead();
            b_uart_testing = false;
        }
        if(b_scanner_testing){
            stopScannerTest();
        }
        if(b_brightness_testing){
            m_led_device.setScreenBrightness(102);
            b_brightness_testing = false;
        }
    }

    private void updateUI(){
        if(b_nfc_testing){
            tx_nfc.setText(R.string.nfc_testing);
        }else {
            tx_nfc.setText(R.string.nfc_closed);
        }
        if(b_uart_testing){
            tx_uart.setText(R.string.uart_opened);
        }else {
            tx_uart.setText(R.string.uart_closed);
        }
        if(b_scanner_testing){
            tx_scanner.setText(R.string.text_scanner_opened);
        }else {
            tx_scanner.setText(R.string.text_scanner_closed);
        }
        if((mPrinter != null) && (mPrinter.getState() == PrintSerializable.CONN_SUCCESS)){
            tx_printer.setText(R.string.text_printer_opened);
        }else {
            tx_printer.setText(R.string.text_printer_closed);
        }
        if(b_brightness_testing){
            tx_brightness.setText(R.string.brightness_test_max);
        }else {
            tx_brightness.setText(R.string.brightness_test_normal);
        }

        String version = "1.0.1";
        try{
            PackageInfo pkg_info = getPackageManager().getPackageInfo(getPackageName(), 0);
            version = pkg_info.versionName;
        }catch (PackageManager.NameNotFoundException e){
        }
        tx_version.setText(getResources().getString(R.string.text_version_prefix) + version);

        if(checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED)
            tx_imei_val.setText((m_system_device == null) ? "unknown" : m_system_device.getDeviceUniqueID());
        tx_temp_val.setText((m_system_device == null) ? "unknown" : String.valueOf(m_system_device.getCPUTemp()));
    }

    @Override
    public void onClick(View v) {
        switch (v.getId()){
            case R.id.btn_nfc:
                if(m_nfc_device == null)
                    break;
                if(b_nfc_testing){
                    handler.removeMessages(MSG_UPDATE_NFC);
                    handler.removeMessages(MSG_LOOP_NFC_DETECT);
                    m_nfc_device.stopRead();
                    b_nfc_testing = false;
                    synchronized (MainActivity.this) {
                        bReading = false;
                    }
                    tx_nfc.setText(R.string.nfc_closed);
                }else {
                    startNFCTest();
                }
                break;
            case R.id.btn_uart:
                if(m_uart_device == null)
                    break;
                if(b_uart_testing){
                    m_uart_device.stopRead();
                    tx_uart.setText(R.string.uart_closed);
                    b_uart_testing = false;
                }else {
                    startUartTest();
                }
                break;
            case R.id.btn_scanner:
                if(m_scanner_device == null)
                    break;
                if(b_scanner_testing){
                    stopScannerTest();
                }else {
                    startScannerTest();
                }
                break;
            case R.id.btn_printer:
                if((mPrinter != null) && (mPrinter.getState() == PrintSerializable.CONN_SUCCESS)){
                    btn_printer.setEnabled(false);
                    mPrinter.init();
                    mPrinter.printText("Printer Test");
                    mPrinter.wrapLines(5);
                    tx_printer.setText(R.string.text_printer_done);
                    btn_printer.setEnabled(true);
                }
                break;
            case R.id.btn_brightness:
                if(m_led_device == null)
                    break;
                if(b_brightness_testing){
                    m_led_device.setScreenBrightness(102);
                    Log.d(TAG, "birghtness is: " + m_led_device.getScreenBrightness());
                    b_brightness_testing = false;
                    tx_brightness.setText(R.string.brightness_test_normal);
                }else {
                    m_led_device.setScreenBrightness(255);
                    Log.d(TAG, "birghtness is: " + m_led_device.getScreenBrightness());
                    b_brightness_testing = true;
                    tx_brightness.setText(R.string.brightness_test_max);
                }
                break;
            case R.id.btn_hide_nav:
                if(m_system_device != null)
                    m_system_device.hideNavigationBar();
                break;
            case R.id.btn_show_nav:
                if(m_system_device != null)
                    m_system_device.showNavigationBar();
                break;
            case R.id.btn_reboot:
                if(m_system_device == null)
                    break;
                m_system_device.reboot();
                break;
            case R.id.btn_self_update:
                /*File f = new File(Environment.getExternalStorageDirectory().getAbsolutePath(), "app_update.apk");
                if(f.exists()){
                    Intent intent = new Intent(Intent.ACTION_VIEW);
                    Uri uri = FileProvider.getUriForFile(this, "test.leshun.hwadaptertest.fileprovider", f);
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    intent.setDataAndType(uri, "application/vnd.android.package-archive");
                    startActivity(intent);
                }else {
                    Log.w(TAG, "app_update.apk not exist!");
                }*/
                m_system_device.silentInstall(this, "/sdcard/test_v999.apk");
                break;
        }
    }

    /*NFC测试，有数据或者错误时会调用回调*/
    private void startNFCTest(){
        timestamp = System.currentTimeMillis();
        b_nfc_testing = true;
        tx_nfc.setText(b_nfc_testing ? R.string.nfc_testing : R.string.nfc_closed);
        handler.sendEmptyMessage(MSG_LOOP_NFC_DETECT);
    }

    /*串口测试，暂采用串口回环方式测试，需硬件做一个tx-rx回环方可测试成功*/
    private void startUartTest(){
        b_uart_testing = m_uart_device.startRead(new HWDataCallBack() {
            @Override
            public void onDataReceived(byte[] bytes, int i) {
                boolean bequal = true;
                if(i == data_send.length){
                    for(int index = 0; index < i; index++){
                        if(bytes[index] != data_send[index]){
                            bequal =false;
                            break;
                        }
                    }
                }else {
                    bequal =false;
                }
                /*因为回调不在主线程里，不可操作UI，故采用Handler方式*/
                Message msg = new Message();
                msg.what = MSG_UPDATE_UART;
                Bundle b = new Bundle();
                b.putBoolean("data", bequal);
                msg.setData(b);
                handler.sendMessage(msg);
            }

            @Override
            public void onError(String s) {
                Log.e(TAG, "uart read error.");
                Message msg = new Message();
                msg.what = MSG_UPDATE_UART;
                Bundle b = new Bundle();
                b.putBoolean("data", false);
                msg.setData(b);
                handler.sendMessage(msg);
            }
        });
        /*往串口发送数据，待收到回调后判断数据是否一致*/
        if(b_uart_testing){
            tx_uart.setText(R.string.uart_opened);
            m_uart_device.write(data_send, data_send.length);
        }
    }

    /*扫码头测试*/
    private void startScannerTest(){
        if(!m_scanner_device.init(this,"/dev/ttyHSL3", 9600)){
            Log.e(TAG, "scanner init error.");
            return;
        }
        b_scanner_testing = m_scanner_device.startRead(new HWDataCallBack() {
            @Override
            public void onDataReceived(byte[] bytes, int i) {
                /*因为回调不在主线程里，不可操作UI，故采用Handler方式*/
                Message msg = new Message();
                msg.what = MSG_UPDATE_SCANNER;
                Bundle b = new Bundle();
                b.putString("data", new String(bytes, 0, i));
                msg.setData(b);
                handler.sendMessage(msg);
            }

            @Override
            public void onError(String s) {
                Log.e(TAG, "scanner read error.");
                Message msg = new Message();
                msg.what = MSG_UPDATE_SCANNER;
                Bundle b = new Bundle();
                b.putString("data", "error");
                msg.setData(b);
                handler.sendMessage(msg);
            }
        });
        tx_scanner.setText(R.string.text_scanner_opened);
    }

    private void stopScannerTest(){
        tx_scanner.setText(R.string.text_scanner_closed);
        b_scanner_testing = false;
        if(m_scanner_device != null) {
            m_scanner_device.stopRead();
            m_scanner_device.deInit();
        }
    }
}
