static char board[264];
static int pieces[56]={
0,0,1,0,2,0,3,0,
0,0,0,1,1,1,2,1,
2,0,0,1,1,1,2,1,
0,0,1,0,0,1,1,1,
1,0,2,0,0,1,1,1,
1,0,0,1,1,1,2,1,
0,0,1,0,1,1,2,1
};
static int cur_shape[8];
static int counts[7];
int score;
unsigned int rand_seed=1234;
int get_rnd(){
if(rand_seed&1){
rand_seed=(rand_seed>>1)^0xA1A1;
}else{
rand_seed=rand_seed>>1;
}
return(int)(rand_seed&32767);
}
int kbhit(){
return bdos(11,0)&255;
}
int getch(){
return bdos(6,255)&255;
}
void put_c(c)
char c;
{
bdos(2,c);
}
void print_str(s)
char *s;
{
while(*s){
bdos(2,*s++);
}
}
void print_num(n,w)
int n,w;
{
char buf[10];
int i;
i=0;
do{
buf[i++]=n%10+'0';
n/=10;
}while(n>0);
while(i<w){
buf[i++]='0';
}
while(i>0){
bdos(2,buf[--i]);
}
}
void clrscr(){
print_str("\033[2J\033[H");
}
void gotoxy(x,y)
int x;
int y;
{
print_str("\033[");
print_num(y,1);
print_str(";");
print_num(x,1);
print_str("H");
}
void draw_stats(){
gotoxy(58,5);print_str("Piece Stats:");
gotoxy(58,7);print_str("I-Piece: ");print_num(counts[0],3);
gotoxy(58,8);print_str("J-Piece: ");print_num(counts[1],3);
gotoxy(58,9);print_str("L-Piece: ");print_num(counts[2],3);
gotoxy(58,10);print_str("O-Piece: ");print_num(counts[3],3);
gotoxy(58,11);print_str("S-Piece: ");print_num(counts[4],3);
gotoxy(58,12);print_str("T-Piece: ");print_num(counts[5],3);
gotoxy(58,13);print_str("Z-Piece: ");print_num(counts[6],3);
}
void draw_board(){
int r,c;
clrscr();
for(r=0;r<21;r++){
for(c=0;c<12;c++){
gotoxy(c*2+10,r+2);
if(board[(r*12)+c]==1){
print_str("##");
}else if(c==0||c==11||r==20){
print_str("<>");
}else{
print_str("  ");
}
}
}
gotoxy(36,5);print_str("Tetris CP/M 2.2");
gotoxy(36,7);print_str("Score: ");print_num(score,4);
gotoxy(36,12);print_str("A = Left, D = Right");
gotoxy(36,13);print_str("W = Rotate, S = Drop");
gotoxy(36,15);print_str("Press Q to Quit");
draw_stats();
}
int can_move(px,py)
int px;
int py;
{
int i,nx,ny;
for(i=0;i<4;i++){
nx=px+cur_shape[i*2];
ny=py+cur_shape[(i*2)+1];
if(nx<1||nx>10||ny>19)return 0;
if(ny<0)continue;
if(board[(ny*12)+nx]==1)return 0;
}
return 1;
}
void draw_piece(px,py,txt)
int px;
int py;
char *txt;
{
int i,nx,ny;
for(i=0;i<4;i++){
nx=px+cur_shape[i*2];
ny=py+cur_shape[(i*2)+1];
if(ny>=0&&ny<=19){
gotoxy(nx*2+10,ny+2);
print_str(txt);
}
}
}
void rotate_piece(){
int i,tx,ty;
for(i=0;i<4;i++){
tx=cur_shape[i*2];
ty=cur_shape[(i*2)+1];
cur_shape[i*2]=2-ty;
cur_shape[(i*2)+1]=tx;
}
}
void check_lines(){
int r,c,l,full,cleared;
cleared=0;
for(r=19;r>=0;r--){
full=1;
for(c=1;c<=10;c++){
if(board[(r*12)+c]==0)full=0;
}
if(full){
cleared++;
for(l=r;l>0;l--){
for(c=1;c<=10;c++){
board[(l*12)+c]=board[((l-1)*12)+c];
}
}
for(c=1;c<=10;c++)board[c]=0;
r++;
}
}
if(cleared>0){
score+=cleared*100;
gotoxy(43,7);
print_num(score,4);
}
}
int main(){
int r,c,i,key,game_over,current_piece,base,active_piece;
int px,py;
long delay,speed_limit;
score=0;
for(i=0;i<7;i++)counts[i]=0;
for(r=0;r<22;r++){
for(c=0;c<12;c++){
board[(r*12)+c]=0;
}
}
draw_board();
current_piece=get_rnd()%7;
game_over=0;
while(!game_over){
counts[current_piece]++;
draw_stats();
base=current_piece*8;
for(i=0;i<4;i++){
cur_shape[i*2]=pieces[base+(i*2)];
cur_shape[(i*2)+1]=pieces[base+(i*2)+1];
}
px=5;
py=0;
if(!can_move(px,py)){
game_over=1;
break;
}
active_piece=1;
while(active_piece){
draw_piece(px,py,"[]");
speed_limit=4000L-((long)score*2L);
if(speed_limit<1200L)speed_limit=1200L;
for(delay=0;delay<speed_limit;delay++){
rand_seed+=1;
if(kbhit()){
key=getch();
if(key=='q'||key=='Q'){
game_over=1;
active_piece=0;
break;
}
if(key=='a'||key=='A'){
if(can_move(px-1,py)){
draw_piece(px,py,"  ");
px--;
draw_piece(px,py,"[]");
}
}
if(key=='d'||key=='D'){
if(can_move(px+1,py)){
draw_piece(px,py,"  ");
px++;
draw_piece(px,py,"[]");
}
}
if(key=='w'||key=='W'){
draw_piece(px,py,"  ");
rotate_piece();
if(!can_move(px,py)){
rotate_piece();
rotate_piece();
rotate_piece();
}
draw_piece(px,py,"[]");
}
if(key=='s'||key=='S'){
delay=speed_limit;
}
}
}
if(!active_piece)break;
if(can_move(px,py+1)){
draw_piece(px,py,"  ");
py++;
}else{
for(i=0;i<4;i++){
int ny=py+cur_shape[(i*2)+1];
int nx=px+cur_shape[i*2];
if(ny>=0){
board[(ny*12)+nx]=1;
}
}
if(py==0||py==1){
game_over=1;
}
active_piece=0;
check_lines();
draw_board();
}
}
if(game_over)break;
current_piece=get_rnd()%7;
}
for(delay=0;delay<10000L;delay++);
while(kbhit()){
getch();
}
clrscr();
gotoxy(1,1);
print_str("Game Over! Final Score: ");
print_num(score,4);
print_str("\nThanks for playing!\n");
return 0;
}
