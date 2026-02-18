using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using PumaSecurity.SDLC.Web.NetFrameworkSdk;

namespace PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests
{
    [TestClass]
    public class CalculatorTests
    {
        private Calculator _calculator;

        [TestInitialize]
        public void Setup()
        {
            _calculator = new Calculator();
        }

        [TestMethod]
        public void Add_TwoPositiveNumbers_ReturnsSum()
        {
            // Arrange
            int a = 5;
            int b = 3;

            // Act
            int result = _calculator.Add(a, b);

            // Assert
            Assert.AreEqual(8, result);
        }

        [TestMethod]
        public void Add_NegativeNumbers_ReturnsCorrectSum()
        {
            // Arrange
            int a = -5;
            int b = -3;

            // Act
            int result = _calculator.Add(a, b);

            // Assert
            Assert.AreEqual(-8, result);
        }

        [TestMethod]
        public void Subtract_TwoNumbers_ReturnsDifference()
        {
            // Arrange
            int a = 10;
            int b = 3;

            // Act
            int result = _calculator.Subtract(a, b);

            // Assert
            Assert.AreEqual(7, result);
        }

        [TestMethod]
        public void Multiply_TwoNumbers_ReturnsProduct()
        {
            // Arrange
            int a = 5;
            int b = 4;

            // Act
            int result = _calculator.Multiply(a, b);

            // Assert
            Assert.AreEqual(20, result);
        }

        [TestMethod]
        public void Divide_ValidNumbers_ReturnsQuotient()
        {
            // Arrange
            int a = 10;
            int b = 2;

            // Act
            double result = _calculator.Divide(a, b);

            // Assert
            Assert.AreEqual(5.0, result);
        }

        [TestMethod]
        [ExpectedException(typeof(DivideByZeroException))]
        public void Divide_ByZero_ThrowsDivideByZeroException()
        {
            // Arrange
            int a = 10;
            int b = 0;

            // Act
            _calculator.Divide(a, b);

            // Assert handled by ExpectedException
        }

        [TestMethod]
        public void IsEven_EvenNumber_ReturnsTrue()
        {
            // Act
            bool result = _calculator.IsEven(4);

            // Assert
            Assert.IsTrue(result);
        }

        [TestMethod]
        public void IsEven_OddNumber_ReturnsFalse()
        {
            // Act
            bool result = _calculator.IsEven(5);

            // Assert
            Assert.IsFalse(result);
        }

        [TestMethod]
        public void IsPositive_PositiveNumber_ReturnsTrue()
        {
            // Act
            bool result = _calculator.IsPositive(10);

            // Assert
            Assert.IsTrue(result);
        }

        [TestMethod]
        public void IsPositive_NegativeNumber_ReturnsFalse()
        {
            // Act
            bool result = _calculator.IsPositive(-5);

            // Assert
            Assert.IsFalse(result);
        }

        [TestMethod]
        public void IsPositive_Zero_ReturnsFalse()
        {
            // Act
            bool result = _calculator.IsPositive(0);

            // Assert
            Assert.IsFalse(result);
        }
    }
}
