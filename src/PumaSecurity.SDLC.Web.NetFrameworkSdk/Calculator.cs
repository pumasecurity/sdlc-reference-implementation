using System;

namespace PumaSecurity.SDLC.Web.NetFrameworkSdk
{
    /// <summary>
    /// Simple calculator for demonstrating testing and code coverage
    /// </summary>
    public class Calculator
    {
        public int Add(int a, int b)
        {
            return a + b;
        }

        public int Subtract(int a, int b)
        {
            return a - b;
        }

        public int Multiply(int a, int b)
        {
            return a * b;
        }

        public double Divide(int a, int b)
        {
            if (b == 0)
            {
                throw new DivideByZeroException("Cannot divide by zero");
            }
            return (double)a / b;
        }

        public int Modulo(int a, int b)
        {
            if (b == 0)
            {
                throw new DivideByZeroException("Cannot perform modulo with zero");
            }
            return a % b;
        }

        public bool IsEven(int number)
        {
            return number % 2 == 0;
        }

        public bool IsPositive(int number)
        {
            return number > 0;
        }
    }
}
