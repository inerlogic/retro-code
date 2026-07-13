#define EOF -1
char buf[128];
int bdos_getch() {
return bdos(1, 0) & 255;
}
int bdos_kbhit() {
return bdos(11, 0) & 255;
}
main(argc, argv)
int argc;
char *argv[];
{
int fd, i, line_count;
char ch;
if (argc < 2) {
printf("Usage: VIEW filename\n");
exit(1);
}
fd = open(argv[1], 0);
if (fd < 0) {
printf("File not found: %s\n", argv[1]);
exit(1);
}
line_count = 0;
while (read(fd, buf, 1) > 0) {
ch = buf[0];
if (ch == 26) {
break;
}
putchar(ch);
if (ch == '\n') {
line_count++;
if (line_count >= 23) {
printf("-- Press SPACE for Page, ENTER for Line, Q to Quit --");
while (1) {
if (bdos_kbhit()) {
i = bdos_getch();
if (i == ' ' || i == '  ') {
printf("\r                                                     \r");
line_count = 0;
break;
}
if (i == 13 || i == 10) {
printf("\r                                                     \r");
line_count = 22;
break;
}
if (i == 'q' || i == 'Q') {
printf("\n");
close(fd);
exit(0);
}
}
}
}
}
}
close(fd);
printf("\n--- End of File ---\n");
}
