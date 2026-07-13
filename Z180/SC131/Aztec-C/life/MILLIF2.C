char cell_a[84];
char cell_b[84];
unsigned int hash_hist[8];
unsigned int rand_seed = 1234;
int get_rnd() {
if (rand_seed & 1) {
rand_seed = (rand_seed >> 1) ^ 0xA1A1;
} else {
rand_seed = rand_seed >> 1;
}
return (rand_seed & 1);
}
int kbhit() {
return bdos(11, 0) & 255;
}
main() {
int x, i, active_count, y_sum, loop_flag;
unsigned int delay, checksum;
printf("Press RETURN to start the Screensaver, Press any key to exit...");
getchar();
for (x = 2; x <= 81; x++) {
cell_a[x] = get_rnd();
}
for (i = 0; i < 8; i++) {
hash_hist[i] = 0;
}
while (1) {
if (kbhit()) {
bdos(1, 0);
printf("\nScreensaver Terminated.\n");
exit(0);
}
active_count = 0;
for (x = 2; x <= 81; x++) {
if (cell_a[x] == 1) {
putchar('*');
active_count++;
} else {
putchar(' ');
}
}
putchar('\n');
if (active_count == 0 || active_count == 80) {
for (x = 2; x <= 81; x++) {
cell_b[x] = get_rnd();
}
} else {
cell_a[0] = cell_a[80];
cell_a[1] = cell_a[81];
cell_a[82] = cell_a[2];
cell_a[83] = cell_a[3];
for (x = 2; x <= 81; x++) {
y_sum = cell_a[x-2] + cell_a[x-1] + cell_a[x+1] + cell_a[x+2];
if (cell_a[x] == 0 && (y_sum == 2 || y_sum == 3)) {
cell_b[x] = 1;
} else if (cell_a[x] == 1 && (y_sum == 2 || y_sum == 4)) {
cell_b[x] = 1;
} else {
cell_b[x] = 0;
}
}
}
checksum = 0;
for (x = 2; x <= 81; x++) {
checksum = (checksum * 3) + cell_b[x];
cell_a[x] = cell_b[x];
}
loop_flag = 0;
for (i = 0; i < 8; i++) {
if (checksum == hash_hist[i]) {
loop_flag = 1;
}
}
for (i = 7; i > 0; i--) {
hash_hist[i] = hash_hist[i-1];
}
hash_hist[0] = checksum;
if (loop_flag == 1) {
printf("\n[LOOP DETECTED! RE-SEEDING...]\n");
for (x = 2; x <= 81; x++) {
cell_a[x] = get_rnd();
}
for (i = 0; i < 8; i++) {
hash_hist[i] = 0;
}
}
for (delay = 0; delay < 12000; delay++) {
}
}
}
