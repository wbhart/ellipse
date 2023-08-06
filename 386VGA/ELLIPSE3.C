#include <math.h>
#include <dos.h>

extern void set_palette();

extern void set_video_mode(int mode);

extern void vga_draw_pixel(int, int, char);

int get_octant(long int D, long int E)
{
   if (D > 0 && E < 0)
   {
      if (D < -E)
         return 1;
      else
         return 2;
   }

   if (D > 0 && E > 0)
   {
      if (D > E)
         return 3;
      else
         return 4;
   }

   if (D < 0 && E > 0)
   {
      if (-D < E)
         return 5;
      else
         return 6;
   }

   if (D < 0 && E < 0)
   {
      if (-D > -E)
         return 7;
      else
         return 8;
   }
}

void conic(int x0, int y0, int xs, int ys, int xe, int ye,
           long int A, long int B, long int C,
           long int D, long int E, long int F, char colour)
{
   int octant = get_octant(D, E), count;
   long int d, u, v, k1, k2, k3;
   long int dSdx, dSdy;
   int dxsquare, dysquare;
   int dxdiag, dydiag;
   int x, y, temp;

   if (octant == 1)
   {
      d = (4*A + 2*B + C + 4*D + 2*E + 4*F + 2)/4;
      u = (2*A + B + 2*D + 1)/2;
      v = (2*A + B + 2*D + 2*E + 1)/2;
      k1 = 2*A;
      k2 = 2*A + B;
      k3 = 2*A + 2*B + 2*C;
      dxsquare = 1;
      dysquare = 0;
      dxdiag = 1;
      dydiag = 1;
   }   

   if (octant == 2)
   {
      d = (A + 2*B + 4*C + 2*D + 4*E + 4*F + 2)/4;
      u = (B + 2*C + 2*E + 1)/2;
      v = (B + 2*C + 2*D + 2*E + 1)/2;
      k1 = 2*C;
      k2 = B + 2*C;
      k3 = 2*A + 2*B + 2*C;
      dxsquare = 0;
      dysquare = 1;
      dxdiag = 1;
      dydiag = 1;
   }   

   if (octant == 3)
   {
      d = (A - 2*B + 4*C - 2*D + 4*E + 4*F + 2)/4;
      u = (-B + 2*C + 2*E + 1)/2;
      v = (-B + 2*C - 2*D + 2*E + 1)/2;
      k1 = 2*C;
      k2 = -B + 2*C;
      k3 = 2*A - 2*B + 2*C;
      dxsquare = 0;
      dysquare = 1;
      dxdiag = -1;
      dydiag = 1;
   }   

   if (octant == 4)
   {
      d = (4*A - 2*B + C - 4*D + 2*E + 4*F + 2)/4;
      u = (2*A - B - 2*D + 1)/2;
      v = (2*A - B - 2*D + 2*E + 1)/2;
      k1 = 2*A;
      k2 = 2*A - B;
      k3 = 2*A - 2*B + 2*C;
      dxsquare = -1;
      dysquare = 0;
      dxdiag = -1;
      dydiag = 1;
   }   

   if (octant == 5)
   {
      d = (4*A + 2*B + C - 4*D - 2*E + 4*F + 2)/4;
      u = (2*A + B - 2*D + 1)/2;
      v = (2*A + B - 2*D - 2*E + 1)/2;
      k1 = 2*A;
      k2 = 2*A + B;
      k3 = 2*A + 2*B + 2*C;
      dxsquare = -1;
      dysquare = 0;
      dxdiag = -1;
      dydiag = -1;
   }   

   if (octant == 6)
   {
      d = (A + 2*B + 4*C - 2*D - 4*E + 4*F + 2)/4;
      u = (B + 2*C - 2*E + 1)/2;
      v = (B + 2*C - 2*D - 2*E + 1)/2;
      k1 = 2*C;
      k2 = B + 2*C;
      k3 = 2*A + 2*B + 2*C;
      dxsquare = 0;
      dysquare = -1;
      dxdiag = -1;
      dydiag = -1;
   }   

   if (octant == 7)
   {
      d = (A - 2*B + 4*C + 2*D - 4*E + 4*F + 2)/4;
      u = (-B + 2*C - 2*E + 1)/2;
      v = (-B + 2*C + 2*D - 2*E + 1)/2;
      k1 = 2*C;
      k2 = -B + 2*C;
      k3 = 2*A - 2*B + 2*C;
      dxsquare = 0;
      dysquare = -1;
      dxdiag = 1;
      dydiag = -1;
   }   

   if (octant == 8)
   {
      d = (4*A - 2*B + C + 4*D - 2*E + 4*F + 2)/4;
      u = (2*A - B + 2*D + 1)/2;
      v = (2*A - B + 2*D - 2*E + 1)/2;
      k1 = 2*A;
      k2 = 2*A - B;
      k3 = 2*A - 2*B + 2*C;
      dxsquare = 1;
      dysquare = 0;
      dxdiag = 1;
      dydiag = -1;
   }   

   x = xe - xs;
   y = ye - ys;
   dSdx = 2*A*x + B*y + D;
   dSdy = B*x + 2*C*y + E;

   count = get_octant(dSdx, dSdy) - octant;

   if (count <= 0)
      count += 8;

   x = xs;
   y = ys;

   while (count > 0)
   {
      if (octant & 1)
      {
         while (v < k2/2)
         {
            vga_draw_pixel(x0 + x, y0 + y, colour);

            if (d < 0)
            {
               x += dxsquare;
               y += dysquare;
               u += k1;
               v += k2;
               d += u;
            } else
            {
               x += dxdiag;
               y += dydiag;
               u += k2;
               v += k3;
               d += v;
            }            
         }

         d = (8*d - 8*u - 4*v - 4*k2 + 3*k3 + 4)/8;
         u = (-2*u + 2*v - k2 + k3 + 1)/2;
         v = (2*v - 2*k2 + k3 + 1)/2;
         k1 = k1 - 2*k2 + k3;
         k2 = k3 - k2;
         temp = dxsquare;
         dxsquare = -dysquare;
         dysquare = temp;
      } else
      {
         while (u < k2/2)
         {
            vga_draw_pixel(x0 + x, y0 + y, colour);

            if (d < 0)
            {
               x += dxdiag;
               y += dydiag;
               u += k2;
               v += k3;
               d += v;
            } else
            {
               x += dxsquare;
               y += dysquare;
               u += k1;
               v += k2;
               d += u;
            }            
         }

         d = d + u - v + k1 - k2;
         v = 2*u - v + k1 - k2;
         u = u + k1 - k2;
         k3 = 4*(k1 - k2) + k3;
         k2 = 2*k1 - k2;
         temp = dxdiag;
         dxdiag = -dydiag;
         dydiag = temp;
      }

      octant += 1;
      if (octant > 8)
         octant -= 8;

      count -= 1;
   }
}

void ellipse_inner(int x0, int y0, int xp, int yp, int xq, int yq, char colour)
{
   int xprod = xp * yq - xq * yp;
   long int A, B, C, D, E, F;
   int temp;

   if (xprod != 0)
   {
      if (xprod < 0)
      {
         temp = xp; xp = xq; xq = temp;
         temp = yp; yp = yq; yq = temp;
         xprod = -xprod;
      }

      A = yp * yp + yq * yq;
      B = -2 * (xp * yp + xq * yq);
      C = xp * xp + xq * xq;
      D = 2 * yq * (long int) xprod;
      E = -2 * xq * (long int) xprod;
      F = 0;

      conic(x0, y0, xp, yp, xp, yp, A, B, C, D, E, F, colour);      
   }
}

void ellipse(int x0, int y0, int a, int b, double theta, char colour)
{
   int xp, yp, xq, yq;

   xp = (int) (a*cos(theta) + 0.5);
   yp = (int) (a*sin(theta) + 0.5);
   xq = (int) (-b*sin(theta) + 0.5);
   yq = (int) (b*cos(theta) + 0.5);

   ellipse_inner(x0, y0, xp, yp, xq, yq, colour);    
}

int main(void)
{
   const double Pi = 3.1415926536;
   double theta;
   int i, k;
   char colour;

   set_video_mode(19);
   set_palette();

   for (k = 20; k < 50; k++)
   {
      for (i = -201; i < 190; i++)
      {
         theta = Pi*i/402;

         colour = 255 - (50 - abs(i)/4);         
         if ((k&3) == 1)
            colour -= 64;
         if ((k&3) == 2)
            colour -= 128;
         if ((k&3) == 3)
            colour -= 193;

         ellipse(160, 100, 50, k, theta, colour);
      }
   }

   getch();

   set_video_mode(3);

   return 0;
}