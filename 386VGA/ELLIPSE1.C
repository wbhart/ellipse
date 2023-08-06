#include <math.h>
#include <dos.h>

extern void set_palette();

extern void set_video_mode(int mode);

extern void vga_ellipse(int, int,
              int, int, int, int, int,
              long int, long int, long int,
              long int, long int, long int, char);

void ellipse(int x0, int y0, int a, int b, double theta, char colour)
{
   double aSq = (double) a * (double) a;
   double c = sqrt(aSq - (double) b * (double) b);
   double Xf = c*cos(theta);
   double Yf = c*sin(theta);
   double XfSq = Xf*Xf;
   double YfSq = Yf*Yf;
   double A = aSq - XfSq;
   double B = -2.0*Xf*Yf;
   double C = aSq - YfSq;
   double D = aSq*(YfSq - A);
   double A2 = A + A;
   double C2 = C + C;
   double k1 = -B/C2;
   double Xv = sqrt(-D/(A + B*k1 + C*k1*k1));
   double Yv = k1*Xv;
   double k2 = -B/A2;
   double Yh = sqrt(-D/(A*k2*k2 + B*k2 + C));
   double Xh = k2*Yh;
   double k3 = (A2 - B)/(C2 - B);
   double Xr = sqrt(-D/(A + B*k3 + C*k3*k3));
   double Yr = k3*Xr;
   double k4 = (-A2 - B)/(C2 + B);
   double Xl = sqrt(-D/(A + B*k4 + C*k4*k4));
   double Yl = k4*Xl;

   int XV, YV, YR, XH, XL, ex, ex1, ex2;
   double Xinit, Yinit, Fn, Fnw, d1;

   if (Xr < Yr*k2)
      Yr = -Yr;
   if (Xl > Yl*k2)
      Xl = -Xl;

   XV = floor(Xv+0.5);
   YV = floor(Yv+0.5);
   YR = floor(Yr+0.5);
   XH = floor(Xh+0.5);
   XL = floor(Xl+0.5);

   Xinit = -0.5 + (double) XV;
   Yinit = 1 + (double) YV;

   Fn = C2*Yinit + B*Xinit + C;
   Fnw = Fn - A2*Xinit - B*Yinit + A - B;
   d1 = (A*Xinit*Xinit) + (B*Xinit*Yinit) + (C*Yinit*Yinit) + D;

   frexp(d1, &ex1);
   frexp(Fnw, &ex2);
   frexp(Fn, &ex);

   if (ex2 > ex)
   {
      ex = ex2;
   }

   if (ex1 > ex)
   {
      ex = ex1;
   }

   ex = -ex;
   if (ex > 0)
      ex = 0;

   ex += 27;

   while (b < 128)
   {
      ex -= 1;
      b <<= 3;
   }

   A = ldexp(A, ex);
   B = ldexp(B, ex);    
   C = ldexp(C, ex);
   Fn = ldexp(Fn, ex);
   Fnw = ldexp(Fnw, ex);
   d1 = ldexp(d1, ex);

   vga_ellipse(x0, y0,
              (int) XV, (int) YV, (int) YR, (int) XH, (int) XL,
              (long int) A, (long int) B, (long int) C,
              (long int) Fn, (long int) Fnw, (long int) d1, colour);
}

int main(void)
{
   const double Pi = 3.1415926536;
   double theta;
   int i, k;
   char colour;

   set_video_mode(19);
   set_palette();

   for (k = 1; k < 100; k++)
   {
      for (i = -201; i <= 201; i++)
      {
         theta = Pi*i/402;

         colour = 255 - (50 - abs(i)/4);         
         if ((k&3) == 1)
            colour -= 64;
         if ((k&3) == 2)
            colour -= 128;
         if ((k&3) == 3)
            colour -= 193;

         ellipse(160, 100, 100, k, theta, colour);
      }
   }

   getch();

   set_video_mode(3);

   return 0;
}