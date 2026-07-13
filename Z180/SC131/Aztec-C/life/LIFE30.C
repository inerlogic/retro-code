char cell_a[82];
char cell_b[82];
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
int x, active_count;
unsigned int delay;
char left, current, right;
printf("Press RETURN to start life30, Press any key to exit...");
getchar();
for (x = 1; x <= 80; x++) {
cell_a[x] = get_rnd();
}
while (1) {
if (kbhit()) {
bdos(1, 0);
printf("\nlife30 Terminated.\n");
exit(0);
}
active_count = 0;
for (x = 1; x <= 80; x++) {
if (cell_a[x] == 1) {
putchar('*');
active_count++;
} else {
putchar(' ');
}
}
putchar('\n');
if (active_count == 0 || active_count == 80) {
for (x = 1; x <= 80; x++) {
cell_b[x] = get_rnd();
}
} else {
cell_a[0] = cell_a[80];
cell_a[81] = cell_a[1];
for (x = 1; x <= 80; x++) {
left = cell_a[x - 1];
current = cell_a[x];
right = cell_a[x + 1];
cell_b[x] = (left ^ (current | right)) ? 1 : 0;
}
}
for (x = 1; x <= 80; x++) {
cell_a[x] = cell_b[x];
}
for (delay = 0; delay < 12000; delay++) {
}
}
}
