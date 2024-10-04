# Visa Addresses (Alias can be used instead of the full address)
import time

import numpy as np
import csv
import pandas as pd
from asics.adc_tester.adc_tester import ADC_Tester

######
data_dir = 'C:/Users/russ_cornell/OneDrive - Cornell University/Desktop/Work/Projects/Testing/ADC/'

bf = ["adc_tester_5.bit", "adc_tester_10.bit", "adc_tester_20.bit"]
clock_rate = ["05MHz", "10MHz", "20MHz"]

v2 = [0.701, 0.726, 0.751, 0.776, 0.801, 0.826, 0.851, 0.876, 0.901, 0.926, 0.951, 0.976, 1.001] # VDD
v1 = [1.602, 1.602, 1.602, 1.602, 1.602, 1.627, 1.652, 1.677, 1.702, 1.727, 1.752, 1.777, 1.802] # VDD Hi
vdd = ["0p700", "0p725", "0p750", "0p775", "0p800", "0p825", "0p850", "0p875", "0p900", "0p925", "0p950", "0p975", "1p000"]
######

vConv_visa_address = 'vConv'
vSource_visa_address = 'vSource'
data_ptr = bytearray(8)

override = False
test_ran = 0
test_total = 0

# Main Code
uut = ADC_Tester(vConv_visa_addr=vConv_visa_address, vSource_addr=vSource_visa_address)
for V in range(len(v2)):
    uut.Set_Supply(v1[V], v2=v2[V], iCmpl1=1e-3, iCmpl2=1e-3)
    if not override:
        time.sleep(5)
    for B in range(len(bf)):
        sentry = True
        test_total = test_total + 1
        bit_file = "C:/Users/russ_cornell/OneDrive - Cornell University/Desktop/Work/Projects/Testing/atepy/instruments/fpga_controllers/base_xem7360/" + bf[B]
        print("----- Attempting: " + clock_rate[B] + " / " + str(vdd[V]) + "V -----")
        if not uut.fpga.InitializeDevice(bit_file=bit_file, override=override):
            print("Bit file " + str(bf[B]) + " failed FPGA Boot on Voltage " + str(v2[V]) + "!!!")
            sentry = False
        override = True
        if sentry :
            uut.fpga.Boot_FPGA()
            if not uut.Boot_ASIC():
                sentry = False
                print("Bit file " + str(bf[B]) + " failed ASIC Boot on Voltage " + str(v2[V]) + "!!!")
            if sentry :
                uut.Reset_ADC()
                uut.vConv.reset()
                uut.vConv.on()
                v_list, data = uut.Meas_Range(v_low=0.0,v_hi=v2[V]+0.025,v_step=0.001,i_comp=1e-4,n=100,data_ptr=data_ptr)
                #v_list, data = uut.Meas_Range(v_low=0.8,v_hi=0.83,v_step=0.01,i_comp=1e-4,n=10,data_ptr=data_ptr)
                print("Success: CLK = " + clock_rate[B] + ", Voltage = " + vdd[V])
                test_ran = test_ran + 1

                # Data Proc
                df = {}
                data_points = []
                for idx in range(len(v_list)):
                    temp = "{:1.4f}".format(v_list[idx])
                    data_points.append(temp)
                    df[temp] = data[idx]
                df = pd.DataFrame(data=df)
                v_med = df.median()
                v_mode = df.mode()
                v_min = df.min()
                v_max = df.max()
                v_avg = df.mean()
                v_std = df.std()
                v_out = ((df < v_avg - 3*v_std) | (df > v_avg + 3*v_std)).sum()

                df.to_csv(data_dir + "raw_adc_samples_" + clock_rate[B] + "_" + vdd[V] + ".csv")
                with open(data_dir + 'summary_stats_' + clock_rate[B] + "_" + vdd[V] + ".csv", 'w', newline='') as csvfile:
                    wr_handle = csv.writer(csvfile, delimiter=',')
                    wr_handle.writerow(['Voltage', 'Median', 'Mode', 'Min', 'Max', 'Avg', 'Std', 'Outliers Count'])
                    for idx in range(len(v_std)):
                        line = [data_points[idx]]
                        line.append('{:.1f}'.format(v_med.iloc[idx]))
                        temp = v_mode.T.iloc[idx].values
                        temp = temp[~np.isnan(temp)]
                        temp = temp.astype(int)
                        temp = [str(x) for x in temp]
                        temp = ', '.join(temp)
                        line.append(temp)
                        line.append(int(v_min.iloc[idx]))
                        line.append(int(v_max.iloc[idx]))
                        line.append('{:.2f}'.format(v_avg.iloc[idx]))
                        line.append('{:.4f}'.format(v_std.iloc[idx]))
                        line.append(v_out.iloc[idx])
                        wr_handle.writerow(line)

uut.Stop_Supply()
uut.vConv.off()
print("----- ALL TESTS COMPLETED ---- " + str(test_ran) + "/" + str(test_total) + " Tests Ran -----")
