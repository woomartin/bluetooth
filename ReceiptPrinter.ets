import { BluetoothPrinterScanner, PrinterDevice } from './BluetoothPrinterScanner';

export enum PrintAlignment {
  LEFT = 0,
  CENTER = 1,
  RIGHT = 2
}

export enum PrintSize {
  NORMAL = 0,
  DOUBLE_HEIGHT = 1,
  DOUBLE_WIDTH = 2,
  DOUBLE_SIZE = 3
}

export class ReceiptPrinter {
  private scanner: BluetoothPrinterScanner;
  private currentDevice?: PrinterDevice;

  constructor() {
    this.scanner = new BluetoothPrinterScanner();
  }

  public async requestPermissions(): Promise<boolean> {
    return await this.scanner.requestPermissions();
  }

  public startScanPrinters(callback: (devices: PrinterDevice[]) => void): void {
    this.scanner.startScan(callback);
  }

  public stopScanPrinters(): void {
    this.scanner.stopScan();
  }

  public async connectPrinter(device: PrinterDevice): Promise<boolean> {
    const connected = await this.scanner.connectToDevice(device);
    if (connected) {
      this.currentDevice = device;
    }
    return connected;
  }

  public async disconnectPrinter(): Promise<void> {
    if (this.currentDevice) {
      await this.scanner.disconnectDevice(this.currentDevice);
      this.currentDevice = undefined;
    }
  }

  public async printText(text: string, alignment: PrintAlignment = PrintAlignment.LEFT, size: PrintSize = PrintSize.NORMAL): Promise<boolean> {
    if (!this.currentDevice) {
      console.error('没有连接的打印机');
      return false;
    }

    const commands: number[] = [];
    
    // 设置对齐方式
    commands.push(0x1B, 0x61, alignment);
    
    // 设置字体大小
    commands.push(0x1D, 0x21, size);
    
    // 添加文本内容
    const textBytes = this.stringToBytes(text);
    commands.push(...textBytes);
    
    // 换行
    commands.push(0x0A);

    const data = new Uint8Array(commands);
    return await this.scanner.sendData(this.currentDevice, data);
  }

  public async printLine(char: string = '-', length: number = 32): Promise<boolean> {
    const line = char.repeat(length);
    return await this.printText(line, PrintAlignment.CENTER);
  }

  public async printQRCode(content: string, size: number = 3): Promise<boolean> {
    if (!this.currentDevice) {
      console.error('没有连接的打印机');
      return false;
    }

    const commands: number[] = [];
    
    // QR码命令序列
    // 设置QR码模块大小
    commands.push(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size);
    
    // 设置QR码纠错等级
    commands.push(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30);
    
    // 存储QR码数据
    const contentBytes = this.stringToBytes(content);
    const dataLength = contentBytes.length + 3;
    commands.push(0x1D, 0x28, 0x6B, dataLength & 0xFF, (dataLength >> 8) & 0xFF, 0x31, 0x50, 0x30);
    commands.push(...contentBytes);
    
    // 打印QR码
    commands.push(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30);
    
    // 换行
    commands.push(0x0A, 0x0A);

    const data = new Uint8Array(commands);
    return await this.scanner.sendData(this.currentDevice, data);
  }

  public async printBarcode(content: string, type: number = 73): Promise<boolean> {
    if (!this.currentDevice) {
      console.error('没有连接的打印机');
      return false;
    }

    const commands: number[] = [];
    
    // 设置条码高度
    commands.push(0x1D, 0x68, 0x64);
    
    // 设置条码宽度
    commands.push(0x1D, 0x77, 0x02);
    
    // 设置条码下方是否打印字符
    commands.push(0x1D, 0x48, 0x02);
    
    // 打印条码
    commands.push(0x1D, 0x6B, type);
    
    const contentBytes = this.stringToBytes(content);
    commands.push(...contentBytes);
    commands.push(0x00);
    
    // 换行
    commands.push(0x0A, 0x0A);

    const data = new Uint8Array(commands);
    return await this.scanner.sendData(this.currentDevice, data);
  }

  public async printReceipt(receiptData: {
    header?: string;
    items: Array<{name: string, quantity: number, price: number}>;
    total: number;
    footer?: string;
  }): Promise<boolean> {
    if (!this.currentDevice) {
      console.error('没有连接的打印机');
      return false;
    }

    // 打印头部
    if (receiptData.header) {
      await this.printText(receiptData.header, PrintAlignment.CENTER, PrintSize.DOUBLE_HEIGHT);
      await this.printLine();
    }

    // 打印商品列表
    for (const item of receiptData.items) {
      const itemLine = `${item.name.padEnd(20)} x${item.quantity} ¥${item.price.toFixed(2)}`;
      await this.printText(itemLine);
    }

    await this.printLine();
    
    // 打印总计
    await this.printText(`总计: ¥${receiptData.total.toFixed(2)}`, PrintAlignment.RIGHT, PrintSize.DOUBLE_WIDTH);
    
    await this.printLine();

    // 打印尾部
    if (receiptData.footer) {
      await this.printText(receiptData.footer, PrintAlignment.CENTER);
    }

    // 切纸
    await this.cutPaper();
    
    return true;
  }

  public async cutPaper(mode: number = 1): Promise<boolean> {
    if (!this.currentDevice) {
      console.error('没有连接的打印机');
      return false;
    }

    const commands = [0x1D, 0x56, mode];
    const data = new Uint8Array(commands);
    return await this.scanner.sendData(this.currentDevice, data);
  }

  public async feedPaper(lines: number = 3): Promise<boolean> {
    if (!this.currentDevice) {
      console.error('没有连接的打印机');
      return false;
    }

    const commands = [0x1B, 0x64, lines];
    const data = new Uint8Array(commands);
    return await this.scanner.sendData(this.currentDevice, data);
  }

  public async initializePrinter(): Promise<boolean> {
    if (!this.currentDevice) {
      console.error('没有连接的打印机');
      return false;
    }

    const commands = [0x1B, 0x40]; // ESC @
    const data = new Uint8Array(commands);
    return await this.scanner.sendData(this.currentDevice, data);
  }

  private stringToBytes(str: string): number[] {
    const bytes: number[] = [];
    for (let i = 0; i < str.length; i++) {
      const charCode = str.charCodeAt(i);
      if (charCode < 128) {
        bytes.push(charCode);
      } else {
        // UTF-8 编码处理
        const utf8Bytes = this.utf8Encode(str.charAt(i));
        bytes.push(...utf8Bytes);
      }
    }
    return bytes;
  }

  private utf8Encode(char: string): number[] {
    const charCode = char.charCodeAt(0);
    const bytes: number[] = [];
    
    if (charCode < 0x80) {
      bytes.push(charCode);
    } else if (charCode < 0x800) {
      bytes.push(0xC0 | (charCode >> 6));
      bytes.push(0x80 | (charCode & 0x3F));
    } else if (charCode < 0x10000) {
      bytes.push(0xE0 | (charCode >> 12));
      bytes.push(0x80 | ((charCode >> 6) & 0x3F));
      bytes.push(0x80 | (charCode & 0x3F));
    } else {
      bytes.push(0xF0 | (charCode >> 18));
      bytes.push(0x80 | ((charCode >> 12) & 0x3F));
      bytes.push(0x80 | ((charCode >> 6) & 0x3F));
      bytes.push(0x80 | (charCode & 0x3F));
    }
    
    return bytes;
  }

  public getConnectedDevice(): PrinterDevice | undefined {
    return this.currentDevice;
  }

  public getScannedDevices(): PrinterDevice[] {
    return this.scanner.getDiscoveredDevices();
  }

  public isScanning(): boolean {
    return this.scanner.isCurrentlyScanning();
  }
}