using PumaSecurity.SDLC.Web.Net;

namespace PumaSecurity.SDLC.Web.Net.Tests;

[TestClass]
public class UserServiceTests
{
    private UserService _userService = null!;

    [TestInitialize]
    public void Setup()
    {
        _userService = new UserService();
    }

    [TestMethod]
    public void AddUser_ValidUser_AddsSuccessfully()
    {
        // Arrange
        var user = new User("jdoe", "john@example.com", "John Doe");

        // Act
        _userService.AddUser(user);

        // Assert
        Assert.AreEqual(1, _userService.GetUserCount());
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void AddUser_NullUser_ThrowsArgumentNullException()
    {
        // Act
        _userService.AddUser(null!);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public void AddUser_EmptyUsername_ThrowsArgumentException()
    {
        // Arrange
        var user = new User("", "john@example.com", "John Doe");

        // Act
        _userService.AddUser(user);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public void AddUser_EmptyEmail_ThrowsArgumentException()
    {
        // Arrange
        var user = new User("jdoe", "", "John Doe");

        // Act
        _userService.AddUser(user);
    }

    [TestMethod]
    [ExpectedException(typeof(InvalidOperationException))]
    public void AddUser_DuplicateUsername_ThrowsInvalidOperationException()
    {
        // Arrange
        var user1 = new User("jdoe", "john@example.com", "John Doe");
        var user2 = new User("jdoe", "jane@example.com", "Jane Doe");

        // Act
        _userService.AddUser(user1);
        _userService.AddUser(user2);
    }

    [TestMethod]
    public void GetUser_ExistingUser_ReturnsUser()
    {
        // Arrange
        var user = new User("jdoe", "john@example.com", "John Doe");
        _userService.AddUser(user);

        // Act
        var result = _userService.GetUser("jdoe");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("jdoe", result.Username);
        Assert.AreEqual("john@example.com", result.Email);
    }

    [TestMethod]
    public void GetUser_NonExistingUser_ReturnsNull()
    {
        // Act
        var result = _userService.GetUser("nonexistent");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public void GetUser_EmptyUsername_ThrowsArgumentException()
    {
        // Act
        _userService.GetUser("");
    }

    [TestMethod]
    public void GetAllUsers_MultipleUsers_ReturnsAllUsers()
    {
        // Arrange
        _userService.AddUser(new User("jdoe", "john@example.com", "John Doe"));
        _userService.AddUser(new User("jsmith", "jane@example.com", "Jane Smith"));

        // Act
        var result = _userService.GetAllUsers();

        // Assert
        Assert.AreEqual(2, result.Count);
    }

    [TestMethod]
    public void DeleteUser_ExistingUser_ReturnsTrue()
    {
        // Arrange
        var user = new User("jdoe", "john@example.com", "John Doe");
        _userService.AddUser(user);

        // Act
        bool result = _userService.DeleteUser("jdoe");

        // Assert
        Assert.IsTrue(result);
        Assert.AreEqual(0, _userService.GetUserCount());
    }

    [TestMethod]
    public void DeleteUser_NonExistingUser_ReturnsFalse()
    {
        // Act
        bool result = _userService.DeleteUser("nonexistent");

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public void UpdateUser_ExistingUser_UpdatesSuccessfully()
    {
        // Arrange
        var user = new User("jdoe", "john@example.com", "John Doe");
        _userService.AddUser(user);

        var updatedUser = new User
        {
            Email = "newemail@example.com",
            FullName = "John Updated Doe",
            IsActive = false
        };

        // Act
        _userService.UpdateUser("jdoe", updatedUser);

        // Assert
        var result = _userService.GetUser("jdoe");
        Assert.IsNotNull(result);
        Assert.AreEqual("newemail@example.com", result.Email);
        Assert.AreEqual("John Updated Doe", result.FullName);
        Assert.IsFalse(result.IsActive);
    }

    [TestMethod]
    [ExpectedException(typeof(InvalidOperationException))]
    public void UpdateUser_NonExistingUser_ThrowsInvalidOperationException()
    {
        // Arrange
        var updatedUser = new User("jdoe", "john@example.com", "John Doe");

        // Act
        _userService.UpdateUser("nonexistent", updatedUser);
    }

    [TestMethod]
    public void GetActiveUsers_MixedUsers_ReturnsOnlyActiveUsers()
    {
        // Arrange
        var user1 = new User("jdoe", "john@example.com", "John Doe") { IsActive = true };
        var user2 = new User("jsmith", "jane@example.com", "Jane Smith") { IsActive = false };
        var user3 = new User("bwilson", "bob@example.com", "Bob Wilson") { IsActive = true };

        _userService.AddUser(user1);
        _userService.AddUser(user2);
        _userService.AddUser(user3);

        // Act
        var result = _userService.GetActiveUsers();

        // Assert
        Assert.AreEqual(2, result.Count);
        Assert.IsTrue(result.TrueForAll(u => u.IsActive));
    }

    [TestMethod]
    public void GetUserCount_EmptyService_ReturnsZero()
    {
        // Act
        int count = _userService.GetUserCount();

        // Assert
        Assert.AreEqual(0, count);
    }
}
