import { ReceiptPrinter, PrintAlignment, PrintSize } from './ReceiptPrinter';
import { PrinterDevice } from './BluetoothPrinterScanner';

@Entry
@Component
struct PrinterDemo {
  @State private printer: ReceiptPrinter = new ReceiptPrinter();
  @State private discoveredPrinters: PrinterDevice[] = [];
  @State private connectedPrinter: PrinterDevice | undefined = undefined;
  @State private isScanning: boolean = false;
  @State private statusMessage: string = '未初始化';

  async aboutToAppear() {
    // 请求蓝牙权限
    const permissionGranted = await this.printer.requestPermissions();
    if (permissionGranted) {
      this.statusMessage = '权限已获取，可以开始扫描';
    } else {
      this.statusMessage = '权限获取失败，请手动授权';
    }
  }

  build() {
    Column({ space: 16 }) {
      // 状态信息
      Text(`状态: ${this.statusMessage}`)
        .fontSize(16)
        .fontColor(Color.Blue)
        .margin({ bottom: 10 })

      // 扫描按钮
      Row({ space: 10 }) {
        Button(this.isScanning ? '停止扫描' : '扫描打印机')
          .onClick(() => {
            if (this.isScanning) {
              this.stopScan();
            } else {
              this.startScan();
            }
          })
          .backgroundColor(this.isScanning ? Color.Red : Color.Green)

        Button('清空列表')
          .onClick(() => {
            this.discoveredPrinters = [];
            this.statusMessage = '设备列表已清空';
          })
          .backgroundColor(Color.Orange)
      }

      // 当前连接的打印机
      if (this.connectedPrinter) {
        Column({ space: 8 }) {
          Text('当前连接:')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          
          Text(`${this.connectedPrinter.deviceName}`)
            .fontSize(16)
            .fontColor(Color.Green)
          
          Text(`MAC: ${this.connectedPrinter.macAddress}`)
            .fontSize(14)
            .fontColor(Color.Gray)

          Button('断开连接')
            .onClick(async () => {
              await this.disconnectPrinter();
            })
            .backgroundColor(Color.Red)
        }
        .alignItems(HorizontalAlign.Start)
        .padding(10)
        .borderRadius(8)
        .backgroundColor('#f0f0f0')
      }

      // 发现的打印机列表
      Text(`发现的打印机 (${this.discoveredPrinters.length})`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      List({ space: 8 }) {
        ForEach(this.discoveredPrinters, (device: PrinterDevice) => {
          ListItem() {
            Column({ space: 4 }) {
              Row() {
                Column({ space: 2 }) {
                  Text(device.deviceName)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                  
                  Text(`类型: ${device.deviceType}`)
                    .fontSize(14)
                    .fontColor(Color.Gray)
                  
                  Text(`信号强度: ${device.rssi} dBm`)
                    .fontSize(12)
                    .fontColor(Color.Gray)
                  
                  Text(`MAC: ${device.macAddress}`)
                    .fontSize(12)
                    .fontColor(Color.Gray)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button(device.connected ? '已连接' : '连接')
                  .onClick(async () => {
                    if (!device.connected) {
                      await this.connectToPrinter(device);
                    }
                  })
                  .backgroundColor(device.connected ? Color.Green : Color.Blue)
                  .enabled(!device.connected)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .padding(10)
            .borderRadius(8)
            .backgroundColor(device.connected ? '#e8f5e8' : '#ffffff')
            .border({
              width: 1,
              color: device.connected ? Color.Green : '#e0e0e0'
            })
          }
        }, (device: PrinterDevice) => device.deviceId)
      }
      .height(300)

      // 打印测试按钮
      if (this.connectedPrinter) {
        Column({ space: 8 }) {
          Text('打印测试')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)

          Row({ space: 10 }) {
            Button('测试文本')
              .onClick(() => this.printTestText())
              .backgroundColor(Color.Blue)

            Button('测试小票')
              .onClick(() => this.printTestReceipt())
              .backgroundColor(Color.Purple)

            Button('测试二维码')
              .onClick(() => this.printTestQRCode())
              .backgroundColor(Color.Orange)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  private startScan(): void {
    this.isScanning = true;
    this.statusMessage = '正在扫描蓝牙打印机...';
    
    this.printer.startScanPrinters((devices: PrinterDevice[]) => {
      this.discoveredPrinters = devices;
      this.statusMessage = `找到 ${devices.length} 台打印机`;
    });

    // 10秒后自动停止扫描
    setTimeout(() => {
      if (this.isScanning) {
        this.stopScan();
      }
    }, 10000);
  }

  private stopScan(): void {
    this.printer.stopScanPrinters();
    this.isScanning = false;
    this.statusMessage = `扫描完成，找到 ${this.discoveredPrinters.length} 台打印机`;
  }

  private async connectToPrinter(device: PrinterDevice): Promise<void> {
    this.statusMessage = `正在连接 ${device.deviceName}...`;
    
    const success = await this.printer.connectPrinter(device);
    if (success) {
      this.connectedPrinter = device;
      this.statusMessage = `成功连接到 ${device.deviceName}`;
      
      // 初始化打印机
      await this.printer.initializePrinter();
    } else {
      this.statusMessage = `连接 ${device.deviceName} 失败`;
    }
  }

  private async disconnectPrinter(): Promise<void> {
    if (this.connectedPrinter) {
      const deviceName = this.connectedPrinter.deviceName;
      await this.printer.disconnectPrinter();
      this.connectedPrinter = undefined;
      this.statusMessage = `已断开与 ${deviceName} 的连接`;
    }
  }

  private async printTestText(): Promise<void> {
    if (!this.connectedPrinter) return;

    this.statusMessage = '正在打印测试文本...';
    
    try {
      await this.printer.printText('=== 打印测试 ===', PrintAlignment.CENTER, PrintSize.DOUBLE_HEIGHT);
      await this.printer.printLine();
      await this.printer.printText('左对齐文本', PrintAlignment.LEFT);
      await this.printer.printText('居中对齐文本', PrintAlignment.CENTER);
      await this.printer.printText('右对齐文本', PrintAlignment.RIGHT);
      await this.printer.printLine();
      await this.printer.printText('正常大小文本', PrintAlignment.LEFT, PrintSize.NORMAL);
      await this.printer.printText('双倍高度文本', PrintAlignment.LEFT, PrintSize.DOUBLE_HEIGHT);
      await this.printer.printText('双倍宽度文本', PrintAlignment.LEFT, PrintSize.DOUBLE_WIDTH);
      await this.printer.printText('双倍大小文本', PrintAlignment.LEFT, PrintSize.DOUBLE_SIZE);
      await this.printer.feedPaper(3);
      
      this.statusMessage = '测试文本打印完成';
    } catch (error) {
      this.statusMessage = '打印测试文本失败';
      console.error('打印失败:', error);
    }
  }

  private async printTestReceipt(): Promise<void> {
    if (!this.connectedPrinter) return;

    this.statusMessage = '正在打印测试小票...';
    
    const receiptData = {
      header: '欢迎光临\n我的商店',
      items: [
        { name: '苹果', quantity: 2, price: 5.00 },
        { name: '香蕉', quantity: 3, price: 3.50 },
        { name: '橙子', quantity: 1, price: 4.20 },
        { name: '牛奶', quantity: 1, price: 12.80 }
      ],
      total: 25.50,
      footer: '谢谢惠顾\n欢迎再次光临!'
    };

    try {
      const success = await this.printer.printReceipt(receiptData);
      if (success) {
        this.statusMessage = '测试小票打印完成';
      } else {
        this.statusMessage = '打印测试小票失败';
      }
    } catch (error) {
      this.statusMessage = '打印测试小票失败';
      console.error('打印失败:', error);
    }
  }

  private async printTestQRCode(): Promise<void> {
    if (!this.connectedPrinter) return;

    this.statusMessage = '正在打印测试二维码...';
    
    try {
      await this.printer.printText('扫描二维码:', PrintAlignment.CENTER);
      await this.printer.printQRCode('https://www.example.com', 6);
      await this.printer.printText('测试二维码', PrintAlignment.CENTER);
      await this.printer.feedPaper(3);
      
      this.statusMessage = '测试二维码打印完成';
    } catch (error) {
      this.statusMessage = '打印测试二维码失败';
      console.error('打印失败:', error);
    }
  }
}