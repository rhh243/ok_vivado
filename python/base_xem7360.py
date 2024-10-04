import instruments.fpga_controllers.ok
import time

from instruments.fpga_controllers import ok


class base_xem7360:
    def __init__(self):
        pass

    def InitializeDevice(self, bit_file, override):
        if not override :
            self.xem = ok.FrontPanelDevices().Open()
        if not self.xem:
            print ("No devices Found!")
            return(False)
        
        # Get some general information about the device.
        self.devInfo = ok.okTDeviceInfo()
        if (self.xem.NoError != self.xem.GetDeviceInfo(self.devInfo)):
            print ("Unable to retrieve device information.")
            return(False)
        print("         Product: " + self.devInfo.productName)
        print("Firmware version: %d.%d" % (self.devInfo.deviceMajorVersion, self.devInfo.deviceMinorVersion))
        print("   Serial Number: %s" % self.devInfo.serialNumber)
        print("       Device ID: %s" % self.devInfo.deviceID)
        
        self.xem.LoadDefaultPLLConfiguration()

        # Download the configuration file.
        if (self.xem.NoError != self.xem.ConfigureFPGA(bit_file)):
            print ("FPGA configuration failed.")
            return(False)

        # Check for FrontPanel support in the FPGA configuration.
        if (False == self.xem.IsFrontPanelEnabled()):
            print ("FrontPanel support is not available.")
            return(False)
        
        print ("FrontPanel support is available.")
        return(True)
    
    def Reset_FPGA(self):
        self.xem.SetWireInValue(0x01, 0, 0xffffffff) # Reset RWr requests

        self.xem.SetWireInValue(0x00, 0x1,0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000000)
        self.xem.SetWireInValue(0x00, 0x0,0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000000)
        
        self.xem.SetWireInValue(0x00, 0x2,0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000000)
        self.xem.SetWireInValue(0x00, 0x0,0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000000)
        
        self.xem.SetWireInValue(0x00, 0x4,0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000000)
        self.xem.SetWireInValue(0x00, 0x0,0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000000)
        
        sentry = False
        sentry2 = 0
        sentry_max = 100
        while (sentry == False and sentry2 < sentry_max) :
            sentry2 = sentry2 + 1
            self.xem.UpdateWireOuts()
            if ((self.xem.GetWireOutValue(0x20) & 0x00000001) and (self.xem.GetWireOutValue(0x20) & 0x6) == 0) :
                sentry = True
        if sentry >= sentry_max :
            print("Reset Timeout - Something is Wrong! - Clocks did not Lock or FIFOs Stuck")
            return(False)
        self.xem.SetWireInValue(0x01, 0, 0xffffffff)
        print("FPGA Reset Success")
        return(True)

    def FPGA_Check(self):
        self.Write_FPGA(0, 0x8, 0x1a0, 0, 0x600D6060)
        data_ptr = bytes(8)
        a = self.Read_FPGA(0, 0x0, 0x1a1, 0, 0, data_ptr)
        a1 = (a[1] & ((2**16)-1)) << 16
        a0 = a[0] & ((2**16)-1)
        a = a0 | a1
        #print(hex(a))
        if a == 0x600D6060:
            return True
        return False

    def Boot_FPGA(self):
        sentry = False
        sentry2 = 0
        sentry_max = 100
        while (sentry == False and sentry2 < sentry_max) :
            sentry2 = sentry2 + 1
            self.Reset_FPGA()
            if (self.FPGA_Check()) :
                sentry = True
        if sentry >= sentry_max :
            print("FPGA Registers Could NOT BOOT")
            return(False)
        self.Reset_SPI()
        print("FPGA Boot Success")
        return True

    def Reset_SPI(self):
        self.Write_FPGA(0,0x8,0x999,0x0,1)
        time.sleep(1/1000)
        self.Write_FPGA(0,0x8,0xAAA,0x0,0)
        time.sleep(1/1000)

    def Write_FPGA(self, uut_flag, cmd, cmd_id, addr, data):
        cmd = cmd | ((uut_flag & 1) << 5)
        cmd = cmd | (1 << 3)

        #bits 63/31 = 0/1 reserved, {62:60, 30:28} = cmd, 
        #   {59:48} = addr, {27:16} = cmd_id, {47:32, 15:0} = data 
        #buffer 7 = bits {31:24}, b6 = {23:16}, b5 = {15:8}, b4 = {7:0}, 
        #      b3 = {63:56}, b2 = {55:48}, b1 = {47:40}, b0 = {39:32}   
        dw0 = ((cmd >> 3) << 28) | (addr << 16) | (data >> 16)
        dw1 = (1 << 31) | ((cmd & (2**3)-1) << 28) | (cmd_id << 16) | (data & (2**16)-1)
        # DEBUG
        #print(hex(dw0))
        #print(hex(dw1))
        self.xem.SetWireInValue(0x01, 0, 0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000)
        self.xem.SetWireInValue(0x02, dw0, 0xffffffff)
        self.xem.SetWireInValue(0x03, dw1, 0xffffffff)
        self.xem.SetWireInValue(0x01, 2, 0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000)
        self.xem.SetWireInValue(0x01, 0, 0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000)
        
        # data_buf = bytearray(8)        
        # data_buf[0] = (data >> 16) & ((2**8)-1)
        # data_buf[1] = (data >> 24) & ((2**8)-1)
        # data_buf[2] = addr & ((2**8)-1)
        # data_buf[3] = (((cmd >> 3) & (2**3)-1) << 4) | ((addr >> 8) & ((2**4)-1))
        # data_buf[4] = data & ((2**8)-1)
        # data_buf[5] = (data >> 8) & ((2**8)-1)
        # data_buf[6] = cmd_id & ((2**8)-1)
        # data_buf[7] = (1 << 7) | ((cmd & (2**3)-1) << 4) | ((cmd_id >> 8) & ((2**4)-1))
        # # DEBUG
        # for idx in range(len(data_buf))
        #     print(hex(data_buf[idx]))
        #self.xem.WriteToBlockPipeIn(0x80, 8, 8, data_buf)
        
    def Read_FPGA(self, uut_flag, cmd, cmd_id, addr, data, data_ptr):
        cmd = cmd | ((uut_flag & 1) << 5)
        cmd = cmd & 2**6 -1 - 8
        
        dw0 = ((cmd >> 3) << 28) | (addr << 16) | (data >> 16)
        dw1 = (1 << 31) | ((cmd & (2**3)-1) << 28) | (cmd_id << 16) | (data & (2**16)-1)
        # DEBUG
        #print(hex(dw0))
        #print(hex(dw1))
        self.xem.SetWireInValue(0x01, 0, 0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000)
        self.xem.SetWireInValue(0x02, dw0, 0xffffffff)
        self.xem.SetWireInValue(0x03, dw1, 0xffffffff)
        self.xem.SetWireInValue(0x01, 2, 0xffffffff)    # Send requested data to r/o queue
        self.xem.UpdateWireIns()
        time.sleep(1/1000)
        self.xem.SetWireInValue(0x01, 0, 0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000)

        self.xem.SetWireInValue(0x01, 4, 0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000)
        self.xem.SetWireInValue(0x01, 0, 0xffffffff)
        self.xem.UpdateWireIns()
        time.sleep(1/1000)

        self.xem.UpdateWireOuts()
        self.xem.UpdateWireOuts()
        return [self.xem.GetWireOutValue(0x23), self.xem.GetWireOutValue(0x22)]
        
        #bits 63/31 = 0/1 reserved, {62:60, 30:28} = cmd, 
        #   {59:48} = addr, {27:16} = cmd_id, {47:32, 15:0} = data 
        #buffer 7 = bits {31:24}, b6 = {23:16}, b5 = {15:8}, b4 = {7:0}, 
        #      b3 = {63:56}, b2 = {55:48}, b1 = {47:40}, b0 = {39:32} 
        # data_buf = bytearray(8)        
        # data_buf[0] = (data >> 16) & ((2**8)-1)
        # data_buf[1] = (data >> 24) & ((2**8)-1)
        # data_buf[2] = addr & ((2**8)-1)
        # data_buf[3] = (((cmd >> 3) & (2**3)-1) << 4) | ((addr >> 8) & ((2**4)-1))
        # data_buf[4] = data & ((2**8)-1)
        # data_buf[5] = (data >> 8) & ((2**8)-1)
        # data_buf[6] = cmd_id & ((2**8)-1)
        # data_buf[7] = (1 << 7) | ((cmd & (2**3)-1) << 4) | ((cmd_id >> 8) & ((2**4)-1))
        # self.xem.WriteToBlockPipeIn(0x80, 8, 8, data_buf)
        # time.sleep(8/1000000)
        # self.xem.ReadFromBlockPipeOut(0xa0, 8, 8, data_ptr)
        
    def FPGA_Debug(self):
        self.xem.UpdateWireOuts()
        print("----- DEBUG (0x20) -----")
        print(hex(self.xem.GetWireOutValue(0x20)))
        print("----- -----")
        print("----- -----")