static char board[22][12];
static int pieces[56] = {
0,0, 1,0, 2,0, 3,0,
0,0, 0,1, 1,1, 2,1,
2,0, 0,1, 1,1, 2,1,
0,0, 1,0, 0,1, 1,1,
1,0, 2,0, 0,1, 1,1,
1,0, 0,1, 1,1, 2,1,
0,0, 1,0, 1,1, 2,1
};
static int cur_shape[4][2];
int score;
int kbhit() {
return bdos(11, 0) & 255;
}
int getch() {
return bdos(6, 255) & 255;
}
clrscr() {
printf("\033[2J\033[H");
}
gotoxy(x, y)
int x, y;
{
printf("\033[%d;%dH", y, x);
}
draw_board() {
int r, c;
clrscr();
for (r = 0; r < 21; r++) {
for (c = 0; c < 12; c++) {
gotoxy(c * 2 + 10, r + 2);
if (board[r][c] == 1) {
printf("##");
} else if (c == 0 || c == 11 || r == 20) {
printf("<>");
} else {
printf("  ");
}
}
}
gotoxy(36, 5);
printf("Tetris CP/M 2.2");
gotoxy(36, 7);
printf("Score: %04d", score);
gotoxy(36, 12);
printf("A = Left, D = Right");
gotoxy(36, 13);
printf("W = Rotate, S = Drop");
gotoxy(36, 15);
printf("Press Q to Quit");
}
int can_move(px, py)
int px, py;
{
int i, nx, ny;
for (i = 0; i < 4; i++) {
nx = px + cur_shape[i][0];
ny = py + cur_shape[i][1];
if (nx < 1 || nx > 10 || ny > 19) return 0;
if (board[ny][nx] == 1) return 0;
}
return 1;
}
draw_piece(px, py, txt)
int px, py;
char *txt;
{
int i;
for (i = 0; i < 4; i++) {
gotoxy((px + cur_shape[i][0]) * 2 + 10, py + cur_shape[i][1] + 2);
printf("%s", txt);
}
}
rotate_piece() {
int i, tx, ty;
for (i = 0; i < 4; i++) {
tx = cur_shape[i][0];
ty = cur_shape[i][1];
cur_shape[i][0] = 2 - ty;
cur_shape[i][1] = tx;
}
}
check_lines() {
int r, c, l, full, cleared;
cleared = 0;
for (r = 19; r >= 0; r--) {
full = 1;
for (c = 1; c <= 10; c++) {
if (board[r][c] == 0) full = 0;
}
if (full) {
cleared++;
for (l = r; l > 0; l--) {
for (c = 1; c <= 10; c++) {
board[l][c] = board[l-1][c];
}
}
for (c = 1; c <= 10; c++) board[0][c] = 0;
r++;
}
}
if (cleared > 0) {
score += cleared * 100;
gotoxy(43, 7);
printf("%04d", score);
}
}
main() {
int r, c, i, key, game_over, current_piece, base;
int px, py;
long delay;
score = 0;
for (r = 0; r < 22; r++) {
for (c = 0; c < 12; c++) {
board[r][c] = 0;
}
}
draw_board();
current_piece = 5;
game_over = 0;
while (!game_over) {
base = current_piece * 8;
for (i = 0; i < 4; i++) {
cur_shape[i][0] = pieces[base + (i*2)];
cur_shape[i][1] = pieces[base + (i*2) + 1];
}
px = 5;
py = 0;
if (!can_move(px, py)) {
game_over = 1;
break;
}
while (1) {
draw_piece(px, py, "[]");
for (delay = 0; delay < 4000; delay++) {
if (kbhit()) {
key = getch();
if (key == 'q' || key == 'Q') {
game_over = 1;
break;
}
if (key == 'a' || key == 'A') {
if (can_move(px - 1, py)) {
draw_piece(px, py, "  ");
px--;
draw_piece(px, py, "[]");
}
}
if (key == 'd' || key == 'D') {
if (can_move(px + 1, py)) {
draw_piece(px, py, "  ");
px++;
draw_piece(px, py, "[]");
}
}
if (key == 'w' || key == 'W') {
draw_piece(px, py, "  ");
rotate_piece();
if (!can_move(px, py)) {
rotate_piece();
rotate_piece();
rotate_piece();
}
draw_piece(px, py, "[]");
}
if (key == 's' || key == 'S') {
delay = 4000;
}
}
}
if (game_over) break;
if (can_move(px, py + 1)) {
draw_piece(px, py, "  ");
py++;
} else {
for (i = 0; i < 4; i++) {
board[py + cur_shape[i][1]][px + cur_shape[i][0]] = 1;
}
check_lines();
draw_board();
break;
}
}
current_piece = (current_piece + 1) % 7;
}
clrscr();
printf("Game Over! Final Score: %04d\n", score);
printf("Thanks for playing!\n");
}
