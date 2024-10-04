import time
from instruments.fpga_controllers import base_xem7360
from instruments.power_supplies import keithley_2280s
from instruments.power_supplies import keithley_2230G
import numpy as np

class ADC_Tester:
    def __init__(self, vConv_visa_addr, vSource_addr):
        self.fpga = base_xem7360()
        self.voltage_src = vConv_visa_addr
        self.vConv = keithley_2280s.KEITHLEY_2280S(visa_address=vConv_visa_addr, name='vConv')
        self.vSource = keithley_2230G.KEITHLEY_2230G(visa_address=vSource_addr, name='vSource')

    def Set_Supply(self,v1,v2,iCmpl1,iCmpl2):
        self.vSource.sel_chan('CH1')
        self.vSource.set_voltage(voltage=v1,iCmpl=iCmpl1)
        self.vSource.sel_chan('CH2')
        self.vSource.set_voltage(voltage=v2,iCmpl=iCmpl2)
        self.vSource.on()
        time.sleep(1)

    def Stop_Supply(self):
        self.vSource.off()
        time.sleep(1/100)

    def Reset_ASIC(self):
        self.fpga.Write_FPGA(uut_flag=1, cmd=0x8, cmd_id=0x333, addr=0, data=1)  # Reset Asic
        self.fpga.Write_FPGA(uut_flag=1, cmd=0x8, cmd_id=0x999, addr=0, data=0)  # Clear reset

    def Check_ASIC(self):
        data_ptr = bytes(8)
        test_load = 0x00000066
        self.fpga.Write_FPGA(uut_flag=1,cmd=0x8,cmd_id=0x555,addr=3,data=test_load) # Write To ASIC Scratch
        self.fpga.Write_FPGA(uut_flag=1,cmd=8,cmd_id=0x111,addr=1,data=3) # Load read pointer with address 3
        a = self.fpga.Read_FPGA(uut_flag=1, cmd=0,cmd_id=0xA5A,addr=1,data=3,data_ptr=data_ptr) # Read from scratch
        a1 = (a[1] & (2**16)-1) << 16
        a0 = a[0] & (2**16)-1
        a = a1 | a0
        if a == test_load:
            return True
        return False

    def Boot_ASIC(self):
        sentry = False
        sentry2 = 0
        sentry_max = 10
        while (sentry == False and sentry2 < sentry_max):
            self.Reset_ASIC()
            if self.Check_ASIC() == True:
                sentry = True
            sentry2 = sentry2 + 1
        if sentry == True:
            print("ASIC Reset and Check Success")
            return True
        print("ASIC FAILED TO CHECK CORRECTLY")
        return False

    def Reset_ADC(self):
        self.fpga.Write_FPGA(uut_flag=1,cmd=8,cmd_id=0x101,addr=0x005,data=1) # Set Reset
        self.fpga.Write_FPGA(uut_flag=1,cmd=8,cmd_id=0x010,addr=0x005,data=0) # Clear Reset

    def Single_ADC(self, data_ptr):
        self.fpga.Write_FPGA(uut_flag=1,cmd=0,cmd_id=0x100,addr=0x005,data=0x00000000) # Prep conversion
        self.fpga.Write_FPGA(uut_flag=1,cmd=0,cmd_id=0x200,addr=0x005,data=0x00000002) # Start conversion
        self.fpga.Write_FPGA(uut_flag=1,cmd=0,cmd_id=0x100,addr=0x005,data=0x00000000) # Prep next conversion
        self.fpga.Write_FPGA(uut_flag=1,cmd=0,cmd_id=0x300,addr=0x001,data=0x00000006) # Load result
        a = self.fpga.Read_FPGA(uut_flag=1,cmd=0,cmd_id=0x400,addr=0x001,data=0x00000006,data_ptr=data_ptr) # Read result
        #Debug
        #for idx in range(len(a)):
        #    print(hex(a[idx]))
        return a[0] & (2**8-1)

    def Set_Voltage(self, v, i_comp):
        self.vConv.set_voltage(voltage = v, iCmpl = i_comp)

    def Meas_Avg(self, v, i_comp, n, data_ptr):
        self.Set_Voltage(v=v, i_comp=i_comp)
        time.sleep(1)
        res = np.zeros(n)
        for idx in range(n):
            res[idx] = int(self.Single_ADC(data_ptr=data_ptr))
        return res

    def Meas_Range(self, v_low, v_hi, v_step, i_comp, n, data_ptr):
        m = int(np.ceil((v_hi - v_low) / v_step)) + 1
        v_arr = np.ones(m) * -1
        arr = np.zeros([m,n])
        v = v_low
        idx = 0
        self.vConv.connection.write(":SYST:KCL 0")
        self.vConv.connection.write(":SYST:BEEP:ERR 0")
        while idx < m:
            v_arr[idx] = v
            arr[idx] = self.Meas_Avg(v=v, i_comp=i_comp, n=n, data_ptr=data_ptr)
            v = v + v_step
            idx = idx + 1
        self.vConv.connection.write(":SYST:KCL 1")
        self.vConv.connection.write(":SYST:BEEP:ERR 1")
        return v_arr, arr