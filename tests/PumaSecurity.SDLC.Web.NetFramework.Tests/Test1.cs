namespace PumaSecurity.SDLC.Web.Tests.Controllers
{
    [TestClass]
    public sealed class HomeControllerTests
    {
        [TestMethod]
        public void Index_ReturnsViewResult()
        {
            // Arrange
            var controller = new PumaSecurity.SDLC.Web.Controllers.HomeController();

            // Act
            var result = controller.Index();

            // Assert
            Assert.IsNotNull(result);
            Assert.IsInstanceOfType(result, typeof(System.Web.Mvc.ViewResult));
        }

        [TestMethod]
        public void About_ReturnsViewResult()
        {
            // Arrange
            var controller = new PumaSecurity.SDLC.Web.Controllers.HomeController();

            // Act
            var result = controller.About();

            // Assert
            Assert.IsNotNull(result);
            Assert.IsInstanceOfType(result, typeof(System.Web.Mvc.ViewResult));
        }

        [TestMethod]
        public void About_SetsViewBagMessage()
        {
            // Arrange
            var controller = new PumaSecurity.SDLC.Web.Controllers.HomeController();

            // Act
            var result = controller.About() as System.Web.Mvc.ViewResult;

            // Assert
            Assert.IsNotNull(result);
            Assert.IsNotNull(result.ViewBag.Message);
            Assert.AreEqual("Your application description page.", result.ViewBag.Message);
        }

        [TestMethod]
        public void Contact_ReturnsViewResult()
        {
            // Arrange
            var controller = new PumaSecurity.SDLC.Web.Controllers.HomeController();

            // Act
            var result = controller.Contact();

            // Assert
            Assert.IsNotNull(result);
            Assert.IsInstanceOfType(result, typeof(System.Web.Mvc.ViewResult));
        }

        [TestMethod]
        public void Contact_SetsViewBagMessage()
        {
            // Arrange
            var controller = new PumaSecurity.SDLC.Web.Controllers.HomeController();

            // Act
            var result = controller.Contact() as System.Web.Mvc.ViewResult;

            // Assert
            Assert.IsNotNull(result);
            Assert.IsNotNull(result.ViewBag.Message);
            Assert.AreEqual("Your contact page.", result.ViewBag.Message);
        }
    }
}
