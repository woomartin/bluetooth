import bluetooth from '@ohos.bluetooth';
import bluetoothManager from '@ohos.bluetoothManager';
import { BusinessError } from '@ohos.base';

export class BluetoothPrinterScanner {
  private discoveryResult: Array<bluetooth.BluetoothRemoteDevice> = [];
  private isScanning: boolean = false;

  /**
   * 初始化蓝牙并开始扫描打印机
   */
  async startScanForPrinters(): Promise<void> {
    try {
      // 检查蓝牙是否启用
      if (!bluetooth.getState()) {
        console.error('蓝牙未开启');
        return;
      }

      // 清空之前的扫描结果
      this.discoveryResult = [];
      this.isScanning = true;

      // 设置扫描参数
      const scanOptions: bluetooth.ScanOptions = {
        interval: 0, // 扫描间隔，0为默认值
        dutyMode: bluetooth.ScanDuty.SCAN_MODE_LOW_POWER, // 低功耗模式
        matchMode: bluetooth.MatchMode.MATCH_MODE_AGGRESSIVE // 积极匹配模式
      };

      // 开始扫描BLE设备
      bluetooth.BLE.startBLEScan(
        [{ // 扫描过滤器，这里可以指定打印机服务UUID
          serviceUuid: "00001101-0000-1000-8000-00805F9B34FB" // SPP服务UUID
        }],
        scanOptions
      );

      // 同时开始经典蓝牙设备发现
      bluetooth.startBluetoothDiscovery();

      // 监听设备发现事件
      this.registerDeviceDiscoveryCallbacks();

      console.log('开始扫描蓝牙打印机...');
    } catch (error) {
      console.error('启动蓝牙扫描失败:', error);
      this.isScanning = false;
    }
  }

  /**
   * 停止扫描
   */
  stopScan(): void {
    try {
      if (this.isScanning) {
        bluetooth.BLE.stopBLEScan();
        bluetooth.stopBluetoothDiscovery();
        this.isScanning = false;
        console.log('停止扫描');
      }
    } catch (error) {
      console.error('停止扫描失败:', error);
    }
  }

  /**
   * 注册设备发现回调
   */
  private registerDeviceDiscoveryCallbacks(): void {
    // 监听经典蓝牙设备发现
    bluetooth.on('bluetoothDeviceFind', (deviceId: string) => {
      console.log('发现蓝牙设备:', deviceId);
      this.handleDeviceFound(deviceId);
    });

    // 监听BLE设备发现
    bluetooth.BLE.on('BLEDeviceFind', (scanResult: Array<bluetooth.ScanResult>) => {
      console.log('发现BLE设备:', scanResult);
      scanResult.forEach(result => {
        this.handleBLEDeviceFound(result);
      });
    });
  }

  /**
   * 处理发现的经典蓝牙设备
   */
  private handleDeviceFound(deviceId: string): void {
    try {
      const remoteDevice = bluetooth.getRemoteDevice(deviceId);
      
      // 检查设备名称是否包含打印机关键词
      if (this.isPrinterDevice(remoteDevice)) {
        this.discoveryResult.push(remoteDevice);
        console.log('发现打印机:', remoteDevice.deviceName, remoteDevice.deviceId);
        
        // 触发回调通知UI更新
        this.onPrinterFound?.(remoteDevice);
      }
    } catch (error) {
      console.error('处理设备发现失败:', error);
    }
  }

  /**
   * 处理发现的BLE设备
   */
  private handleBLEDeviceFound(scanResult: bluetooth.ScanResult): void {
    try {
      const device = scanResult.deviceId;
      const deviceName = scanResult.data?.localName || '';
      
      if (this.isPrinterDeviceByName(deviceName)) {
        console.log('发现BLE打印机:', deviceName, device);
        
        // 创建远程设备对象
        const remoteDevice: bluetooth.BluetoothRemoteDevice = {
          deviceId: device,
          deviceName: deviceName,
          deviceType: bluetooth.BluetoothDeviceType.DEVICE_TYPE_UNKNOWN,
          connectionState: bluetooth.ProfileConnectionState.STATE_DISCONNECTED
        };
        
        this.discoveryResult.push(remoteDevice);
        this.onPrinterFound?.(remoteDevice);
      }
    } catch (error) {
      console.error('处理BLE设备发现失败:', error);
    }
  }

  /**
   * 判断是否为打印机设备
   */
  private isPrinterDevice(device: bluetooth.BluetoothRemoteDevice): boolean {
    return this.isPrinterDeviceByName(device.deviceName || '');
  }

  /**
   * 通过设备名称判断是否为打印机
   */
  private isPrinterDeviceByName(deviceName: string): boolean {
    const printerKeywords = [
      'printer', 'print', '打印', 
      'canon', 'hp', 'epson', 'brother', 
      'zebra', 'tsc', 'godex', 'argox',
      'pos', 'receipt', '小票'
    ];
    
    const lowerName = deviceName.toLowerCase();
    return printerKeywords.some(keyword => 
      lowerName.includes(keyword.toLowerCase())
    );
  }

  /**
   * 连接到打印机
   */
  async connectToPrinter(device: bluetooth.BluetoothRemoteDevice): Promise<boolean> {
    try {
      console.log('尝试连接到打印机:', device.deviceName);
      
      // 配对设备（如果未配对）
      const pairedDevices = bluetooth.getPairedDevices();
      const isPaired = pairedDevices.some(d => d.deviceId === device.deviceId);
      
      if (!isPaired) {
        const success = await bluetooth.pairDevice(device.deviceId);
        if (!success) {
          console.error('配对失败');
          return false;
        }
      }

      // 这里可以根据具体的打印机协议建立连接
      // 例如通过SPP (Serial Port Profile) 连接
      console.log('打印机连接成功');
      return true;
      
    } catch (error) {
      console.error('连接打印机失败:', error);
      return false;
    }
  }

  /**
   * 获取扫描到的打印机列表
   */
  getPrinterList(): Array<bluetooth.BluetoothRemoteDevice> {
    return this.discoveryResult;
  }

  /**
   * 打印机发现回调
   */
  onPrinterFound?: (device: bluetooth.BluetoothRemoteDevice) => void;

  /**
   * 清理资源
   */
  destroy(): void {
    this.stopScan();
    bluetooth.off('bluetoothDeviceFind');
    bluetooth.BLE.off('BLEDeviceFind');
  }
}

// 使用示例
export class PrinterScanPage {
  private scanner: BluetoothPrinterScanner;
  private printerList: Array<bluetooth.BluetoothRemoteDevice> = [];

  constructor() {
    this.scanner = new BluetoothPrinterScanner();
    
    // 设置打印机发现回调
    this.scanner.onPrinterFound = (device) => {
      this.printerList.push(device);
      this.updateUI(); // 更新界面显示
    };
  }

  /**
   * 开始扫描按钮点击事件
   */
  async onStartScanClick(): Promise<void> {
    try {
      await this.scanner.startScanForPrinters();
      
      // 10秒后自动停止扫描
      setTimeout(() => {
        this.scanner.stopScan();
      }, 10000);
      
    } catch (error) {
      console.error('扫描失败:', error);
    }
  }

  /**
   * 连接打印机
   */
  async onConnectPrinter(device: bluetooth.BluetoothRemoteDevice): Promise<void> {
    const success = await this.scanner.connectToPrinter(device);
    if (success) {
      console.log('连接成功，可以开始打印');
      // 这里可以调用具体的打印方法
    }
  }

  /**
   * 更新UI界面
   */
  private updateUI(): void {
    // 更新打印机列表显示
    console.log('当前发现的打印机数量:', this.printerList.length);
    this.printerList.forEach((printer, index) => {
      console.log(`${index + 1}. ${printer.deviceName} (${printer.deviceId})`);
    });
  }

  /**
   * 页面销毁时清理资源
   */
  onDestroy(): void {
    this.scanner.destroy();
  }
}