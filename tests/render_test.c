// Offline test: renders each drive through power-on, live bursts, ambient, busy, power-off.
#include "../Sources/DriveSynth.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#define SR 48000
#define BLOCK 512

static void wav_write(const char *path, const float *x, int n) {
    FILE *f = fopen(path, "wb");
    int32_t sr = SR, byteRate = SR * 2, dataLen = n * 2, riffLen = 36 + dataLen;
    int16_t ch = 1, bits = 16, align = 2, fmt = 1; int32_t fmtLen = 16;
    fwrite("RIFF", 1, 4, f); fwrite(&riffLen, 4, 1, f); fwrite("WAVEfmt ", 1, 8, f);
    fwrite(&fmtLen, 4, 1, f); fwrite(&fmt, 2, 1, f); fwrite(&ch, 2, 1, f); fwrite(&sr, 4, 1, f);
    fwrite(&byteRate, 4, 1, f); fwrite(&align, 2, 1, f); fwrite(&bits, 2, 1, f);
    fwrite("data", 1, 4, f); fwrite(&dataLen, 4, 1, f);
    for (int i = 0; i < n; i++) { float v = x[i]; if (v > 1) v = 1; if (v < -1) v = -1; int16_t s = (int16_t)(v * 32767); fwrite(&s, 2, 1, f); }
    fclose(f);
}

int main(int argc, char **argv) {
    const char *names[] = {"floppy35", "floppy525", "stepper", "ide", "desktop", "server"};
    int secs = 60;
    int total = SR * secs;
    float *buf = malloc(sizeof(float) * total);
    for (int prof = 0; prof < DS_PROFILE_COUNT; prof++) {
        DriveSynth *s = ds_create(SR, 1234 + prof);
        ds_set_profile(s, prof);
        ds_set_volume(s, 0.6f);
        ds_set_hum(s, 0.7f);
        ds_set_mode(s, DS_MODE_LIVE);
        int n = 0, nans = 0; double sumsq = 0; float peak = 0;
        int silentAt = -1, readyAt = -1; double ledR = 0, ledW = 0; int statusCalls = 0;
        float minHead = 9, maxHead = -9;
        for (int b = 0; n < total; b++) {
            double t = (double)n / SR;
            // timeline
            if (b == 0) ds_set_power(s, 1);
            // live activity 12..24 s: bursts every 100 ms
            if (t >= 12 && t < 24 && (b % 9) == 0) {
                int burst = ((int)(t * 10) % 30 < 8) ? 400 : 25; // heavy for 0.8 s every 3 s
                ds_post_activity(s, burst, burst / 2, (uint64_t)burst * 65536, (uint64_t)burst * 16384);
            }
            if (t >= 24 && t < 24.02) ds_set_mode(s, DS_MODE_AMBIENT);
            if (t >= 34 && t < 34.02) ds_set_mode(s, DS_MODE_BUSY);
            if (t >= 44 && t < 44.02) ds_set_power(s, 0);
            int fr = BLOCK; if (n + fr > total) fr = total - n;
            ds_render(s, buf + n, fr);
            DSStatus st; ds_get_status(s, &st);
            statusCalls++; ledR += st.readLED; ledW += st.writeLED;
            if (st.headPos < minHead) minHead = st.headPos;
            if (st.headPos > maxHead) maxHead = st.headPos;
            if (readyAt < 0 && st.ready) readyAt = n;
            if (t > 44 && silentAt < 0 && st.silent) silentAt = n;
            n += fr;
        }
        for (int i = 0; i < total; i++) {
            float v = buf[i];
            if (!isfinite(v)) nans++;
            sumsq += v * v; if (fabsf(v) > peak) peak = fabsf(v);
        }
        // segment rms
        double seg[6] = {0}; int segb[6] = {0, 4, 12, 24, 34, 44}; int sege[6] = {4, 12, 24, 34, 44, 60};
        for (int k = 0; k < 6; k++) {
            double ss = 0; float pk = 0;
            for (int i = segb[k] * SR; i < sege[k] * SR; i++) { ss += buf[i] * buf[i]; if (fabsf(buf[i]) > pk) pk = fabsf(buf[i]); }
            seg[k] = 20 * log10(sqrt(ss / ((sege[k] - segb[k]) * SR)) + 1e-12);
            printf("  %s seg %2d-%2ds rms %6.1f dB  peak %5.3f\n", names[prof], segb[k], sege[k], seg[k], pk);
        }
        printf("%s: nans=%d peak=%.3f ready=%.2fs silent=%.2fs ledR=%.3f ledW=%.3f head[%.2f,%.2f]\n",
               names[prof], nans, peak, readyAt / (double)SR, silentAt / (double)SR,
               ledR / statusCalls, ledW / statusCalls, minHead, maxHead);
        char path[256]; snprintf(path, sizeof path, "out_%s.wav", names[prof]);
        wav_write(path, buf, total);
        ds_destroy(s);
    }
    free(buf);
    return 0;
}
