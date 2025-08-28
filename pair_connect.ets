import bluetooth from '@ohos.bluetooth';

// 获取已配对的设备
function getPairedDevices() {
  let pairedDevices = bluetooth.getPairedDevices();
  console.info("已配对设备列表：", JSON.stringify(pairedDevices));

  pairedDevices.forEach((device) => {
    console.info(`设备名称: ${device.name}, 地址: ${device.deviceId}`);
  });
}

// 判断某个设备是否已连接
function checkDeviceConnection(deviceId: string) {
  let device = bluetooth.createBluetoothDevice(deviceId);
  if (!device) {
    console.error("未找到设备: " + deviceId);
    return;
  }

  let state = device.getConnectionState(); // 返回 0/1/2
  switch (state) {
    case bluetooth.ProfileConnectionState.STATE_DISCONNECTED:
      console.info("设备未连接");
      break;
    case bluetooth.ProfileConnectionState.STATE_CONNECTING:
      console.info("设备正在连接中...");
      break;
    case bluetooth.ProfileConnectionState.STATE_CONNECTED:
      console.info("设备已连接");
      break;
    case bluetooth.ProfileConnectionState.STATE_DISCONNECTING:
      console.info("设备正在断开中...");
      break;
  }
}

// 示例调用
getPairedDevices();

// 假设要检查某个设备是否连接（例如已配对设备的 deviceId）
checkDeviceConnection("11:22:33:AA:BB:CC");
