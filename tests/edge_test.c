#include "../Sources/DriveSynth.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
int main(void){
  DriveSynth *s = ds_create(48000, 7);
  float buf[512]; int nans=0; float peak=0;
  ds_set_volume(s,1.0f); ds_set_hum(s,1.0f);
  // rapid toggling + profile switches + steady 20 ops/s background
  double t=0; double ledR=0, ledW=0; int calls=0;
  for (int b=0; b< 48000*90/512; b++){
    t = b*512/48000.0;
    if (b%9==0) ds_post_activity(s, 1, 1, 8192, 16384); // ~10 r + 10 w per sec
    if (b==1) ds_set_power(s,1);
    if (b==200) ds_set_power(s,0);
    if (b==203) ds_set_power(s,1);
    if (b==600) ds_set_profile(s,0);
    if (b==640) ds_set_profile(s,2);
    if (b==900) ds_set_profile(s,5);
    if (b==1500) ds_set_profile(s,1);
    if (b==1600) ds_set_power(s,0);
    if (b==1610) ds_set_profile(s,3);
    if (b==1700) ds_set_power(s,1);
    ds_render(s, buf, 512);
    for(int i=0;i<512;i++){ if(!isfinite(buf[i])) nans++; if(fabsf(buf[i])>peak) peak=fabsf(buf[i]); }
    DSStatus st; ds_get_status(s,&st);
    if (t>30 && t<55){ ledR+=st.readLED; ledW+=st.writeLED; calls++; }
    if (b%400==0) printf("t=%5.1f prof=%d power=%d ready=%d silent=%d spin=%.2f head=%.2f\n", t, st.profile, st.power, st.ready, st.silent, st.spin, st.headPos);
  }
  printf("nans=%d peak=%.3f server-idle-ish ledR=%.3f ledW=%.3f\n", nans, peak, ledR/calls, ledW/calls);
  ds_destroy(s); return 0;
}
