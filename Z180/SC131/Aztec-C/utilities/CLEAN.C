char out_name[50];
main(argc, argv)
int argc;
char *argv[];
{
if (argc < 2) {
printf("Usage: CLEAN program_name\n");
exit(1);
}
strcpy(out_name, argv[1]);
strcat(out_name, ".asm");
if (unlink(out_name) == 0) {
printf("Deleted: %s\n", out_name);
}
strcpy(out_name, argv[1]);
strcat(out_name, ".o");
if (unlink(out_name) == 0) {
printf("Deleted: %s\n", out_name);
}
strcpy(out_name, argv[1]);
strcat(out_name, ".bak");
if (unlink(out_name) == 0) {
printf("Deleted: %s\n", out_name);
}
printf("Cleanup complete!\n");
}
