import { access, Permissions } from '@ohos.abilityAccessCtrl';
import bluetoothManager from '@ohos.bluetoothManager';
import { BusinessError } from '@ohos.base';

export interface PrinterDevice {
  deviceId: string;
  deviceName: string;
  deviceType: string;
  rssi: number;
  macAddress: string;
  connected: boolean;
}

export class BluetoothPrinterScanner {
  private isScanning: boolean = false;
  private discoveredDevices: PrinterDevice[] = [];
  private scanCallback?: (devices: PrinterDevice[]) => void;
  private connectionCallback?: (device: PrinterDevice, connected: boolean) => void;

  constructor() {
    this.initBluetooth();
  }

  private initBluetooth(): void {
    try {
      if (!bluetoothManager.isBluetoothEnabled()) {
        console.log('蓝牙未开启，正在启用...');
        bluetoothManager.enableBluetooth();
      }
    } catch (error) {
      console.error('初始化蓝牙失败:', error);
    }
  }

  public async requestPermissions(): Promise<boolean> {
    const permissions: Permissions[] = [
      'ohos.permission.ACCESS_BLUETOOTH',
      'ohos.permission.MANAGE_BLUETOOTH',
      'ohos.permission.DISCOVER_BLUETOOTH',
      'ohos.permission.LOCATION'
    ];

    try {
      for (const permission of permissions) {
        const result = await access.verifyAccessToken(permission);
        if (result !== access.GrantStatus.PERMISSION_GRANTED) {
          console.error(`权限 ${permission} 未授予`);
          return false;
        }
      }
      return true;
    } catch (error) {
      console.error('检查权限失败:', error);
      return false;
    }
  }

  public startScan(callback?: (devices: PrinterDevice[]) => void): void {
    if (this.isScanning) {
      console.log('正在扫描中...');
      return;
    }

    this.scanCallback = callback;
    this.discoveredDevices = [];
    
    try {
      if (!bluetoothManager.isBluetoothEnabled()) {
        console.error('蓝牙未启用');
        return;
      }

      const scanOptions: bluetoothManager.ScanOptions = {
        interval: 0,
        dutyMode: bluetoothManager.ScanDuty.SCAN_MODE_LOW_POWER,
        matchMode: bluetoothManager.MatchMode.MATCH_MODE_AGGRESSIVE
      };

      bluetoothManager.on('bluetoothDeviceFind', (data: Array<string>) => {
        this.handleDeviceFound(data);
      });

      bluetoothManager.startBluetoothDiscovery();
      this.isScanning = true;
      console.log('开始扫描蓝牙设备...');

      setTimeout(() => {
        this.stopScan();
      }, 10000);

    } catch (error) {
      console.error('启动蓝牙扫描失败:', error);
      this.isScanning = false;
    }
  }

  public stopScan(): void {
    if (!this.isScanning) {
      return;
    }

    try {
      bluetoothManager.stopBluetoothDiscovery();
      bluetoothManager.off('bluetoothDeviceFind');
      this.isScanning = false;
      console.log('停止扫描蓝牙设备');
    } catch (error) {
      console.error('停止蓝牙扫描失败:', error);
    }
  }

  private handleDeviceFound(deviceIds: Array<string>): void {
    deviceIds.forEach(deviceId => {
      try {
        const device = bluetoothManager.getRemoteDevice(deviceId);
        const deviceName = device.getDeviceName() || '未知设备';
        
        if (this.isPrinterDevice(deviceName)) {
          const printerDevice: PrinterDevice = {
            deviceId: deviceId,
            deviceName: deviceName,
            deviceType: this.getDeviceType(device),
            rssi: device.getRssiValue() || -100,
            macAddress: deviceId,
            connected: device.getConnectionState() === bluetoothManager.ProfileConnectionState.STATE_CONNECTED
          };

          const existingIndex = this.discoveredDevices.findIndex(d => d.deviceId === deviceId);
          if (existingIndex >= 0) {
            this.discoveredDevices[existingIndex] = printerDevice;
          } else {
            this.discoveredDevices.push(printerDevice);
          }

          console.log(`发现打印机设备: ${deviceName} (${deviceId})`);
          
          if (this.scanCallback) {
            this.scanCallback([...this.discoveredDevices]);
          }
        }
      } catch (error) {
        console.error(`处理设备 ${deviceId} 时出错:`, error);
      }
    });
  }

  private isPrinterDevice(deviceName: string): boolean {
    const printerKeywords = [
      'printer', 'print', '打印', 'thermal', 'receipt', 'pos',
      'xprinter', 'gprinter', 'hprt', 'sunmi', 'citizen',
      'epson', 'star', 'bixolon', 'custom', 'rongta'
    ];

    const lowerDeviceName = deviceName.toLowerCase();
    return printerKeywords.some(keyword => 
      lowerDeviceName.includes(keyword.toLowerCase())
    );
  }

  private getDeviceType(device: bluetoothManager.BluetoothRemoteDevice): string {
    try {
      const deviceClass = device.getDeviceClass();
      if (deviceClass && deviceClass.majorClass === bluetoothManager.MajorClass.MAJOR_IMAGING) {
        return 'Thermal Printer';
      }
      return 'Unknown Printer';
    } catch (error) {
      return 'Unknown Device';
    }
  }

  public async connectToDevice(device: PrinterDevice): Promise<boolean> {
    try {
      const remoteDevice = bluetoothManager.getRemoteDevice(device.deviceId);
      
      const connectPromise = new Promise<boolean>((resolve) => {
        const connectCallback = (deviceId: string, state: bluetoothManager.ProfileConnectionState) => {
          if (deviceId === device.deviceId) {
            if (state === bluetoothManager.ProfileConnectionState.STATE_CONNECTED) {
              console.log(`成功连接到打印机: ${device.deviceName}`);
              device.connected = true;
              if (this.connectionCallback) {
                this.connectionCallback(device, true);
              }
              resolve(true);
            } else if (state === bluetoothManager.ProfileConnectionState.STATE_DISCONNECTED) {
              console.log(`打印机连接断开: ${device.deviceName}`);
              device.connected = false;
              if (this.connectionCallback) {
                this.connectionCallback(device, false);
              }
              resolve(false);
            }
          }
        };

        bluetoothManager.on('connectionStateChange', connectCallback);
        
        setTimeout(() => {
          bluetoothManager.off('connectionStateChange', connectCallback);
          resolve(false);
        }, 10000);
      });

      remoteDevice.connect();
      return await connectPromise;

    } catch (error) {
      console.error(`连接打印机失败: ${device.deviceName}`, error);
      return false;
    }
  }

  public async disconnectDevice(device: PrinterDevice): Promise<void> {
    try {
      const remoteDevice = bluetoothManager.getRemoteDevice(device.deviceId);
      remoteDevice.disconnect();
      device.connected = false;
      console.log(`断开打印机连接: ${device.deviceName}`);
    } catch (error) {
      console.error(`断开连接失败: ${device.deviceName}`, error);
    }
  }

  public async sendData(device: PrinterDevice, data: Uint8Array): Promise<boolean> {
    if (!device.connected) {
      console.error('设备未连接');
      return false;
    }

    try {
      const remoteDevice = bluetoothManager.getRemoteDevice(device.deviceId);
      await remoteDevice.sendData(data);
      console.log(`数据发送成功到 ${device.deviceName}`);
      return true;
    } catch (error) {
      console.error(`发送数据失败:`, error);
      return false;
    }
  }

  public setConnectionCallback(callback: (device: PrinterDevice, connected: boolean) => void): void {
    this.connectionCallback = callback;
  }

  public getDiscoveredDevices(): PrinterDevice[] {
    return [...this.discoveredDevices];
  }

  public isCurrentlyScanning(): boolean {
    return this.isScanning;
  }

  public clearDeviceList(): void {
    this.discoveredDevices = [];
  }
}