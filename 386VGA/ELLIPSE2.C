#include <math.h>
#include <dos.h>

extern void set_palette();

extern void set_video_mode(int mode);

extern void vga_ellipse(int, int,
              int, int, int, int, int,
              long int, long int, long int,
              long int, long int, long int, char);

extern void vga_draw_pixel(int, int, char);

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
   double B2 = B + B;
   double B_2 = B/2;
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

   int XV, YV, YR, XH, XL, ex, ex1, ex2, x, y;
   double Xinit, Yinit, Fn, Fnw, Fw, Fsw, Fs, d1, d2, d3, d4;
   double Fn_n = C2, Fw_w = A2, Fs_s = C2;
   double Fn_nw = C2 - B, Fnw_n = C2 - B;
   double Fw_nw = A2 - B, Fnw_w = A2 - B;
   double Fw_sw = A2 + B, Fsw_w = A2 + B;
   double Fnw_nw = A2 - B2 + C2;
   double Fsw_sw = A2 + B2 + C2;
   double Fs_sw = C2 + B, Fsw_s = C2 + B;

   double cross1 = B - A;
   double cross2 = A - B + C;
   double cross3 = A + B + C;
   double cross4 = A + B;   

   if (Xr < Yr*k2)
      Yr = -Yr;
   if (Xl > Yl*k2)
      Xl = -Xl;

   XV = floor(Xv+0.5);
   YV = floor(Yv+0.5);
   YR = floor(Yr+0.5);
   XH = floor(Xh+0.5);
   XL = floor(Xl+0.5);

   x = XV;
   y = YV;

   Xinit = -0.5 + (double) XV;
   Yinit = 1 + (double) YV;

   Fn = C2*Yinit + B*Xinit + C;
   Fnw = Fn - A2*Xinit - B*Yinit + A - B;
   d1 = (A*Xinit*Xinit) + (B*Xinit*Yinit) + (C*Yinit*Yinit) + D;

   while (y < YR)
   {
       vga_draw_pixel(x0 + x, y0 + y, colour);
       vga_draw_pixel(x0 - x, y0 - y, colour);
       y += 1;

       if (d1 < 0 || Fn - Fnw < cross1)
       {
           d1 += Fn;
           Fn += Fn_n;
           Fnw += Fnw_n;
       } else
       {
           x -= 1;

           d1 += Fnw;
           Fn += Fn_nw;
           Fnw += Fnw_nw;
       }
   }
   
   Fw = Fnw - Fn + A + B + B_2;
   Fnw = Fnw + A - C;
   d2 = d1 + (Fw - Fn + C)/2 + (A + C)/4 - A;

   while (x > XH)
   {
       vga_draw_pixel(x0 + x, y0 + y, colour);
       vga_draw_pixel(x0 - x, y0 - y, colour);
       x -= 1;

       if (d2 < 0 || Fnw - Fw < cross2)
       {
           y += 1;

           d2 += Fnw;
           Fw += Fw_nw;
           Fnw += Fnw_nw;   
       } else
       {
           d2 += Fw;
           Fw += Fw_w;
           Fnw += Fnw_w;   
       }
   }

   d3 = d2 + Fw - Fnw + C2 - B;
   Fw += B;
   Fsw = Fw - Fnw + Fw + C2 + C2 - B;

   while (x > XL)
   {
      vga_draw_pixel(x0 + x, y0 + y, colour);
      vga_draw_pixel(x0 - x, y0 - y, colour);
      x -= 1;

      if (d3 < 0 || Fsw - Fw > cross3)
      {
         d3 += Fw;
         Fw += Fw_w;
         Fsw += Fsw_w;
      } else
      {
         y -= 1;

         d3 += Fsw;
         Fw += Fw_sw;
         Fsw += Fsw_sw;
      } 
   }   

   Fs = Fsw - Fw - B;
   d4 = d3 - Fsw/2 + Fs + A - (A + C - B)/4;
   Fsw = Fsw + C - A;
   Fs = Fs + C - B_2;

   YV = -YV;

   while (y > YV)
   {
      vga_draw_pixel(x0 + x, y0 + y, colour);
      vga_draw_pixel(x0 - x, y0 - y, colour);
      y -= 1;

      if (d4 < 0 || Fsw - Fs < cross4)
      {
          x -= 1;

          d4 += Fsw;
          Fs += Fs_sw;
          Fsw += Fsw_sw;
      } else
      {
          d4 += Fs;
          Fs += Fs_s;
          Fsw += Fsw_s;
      }     
   }

   vga_draw_pixel(x0 + x, y0 + y, colour);
   vga_draw_pixel(x0 - x, y0 - y, colour);

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