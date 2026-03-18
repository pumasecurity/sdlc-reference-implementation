using System;
using System.Collections.Generic;
using System.Linq;

namespace PumaSecurity.SDLC.Web.NetFrameworkSdk
{
    /// <summary>
    /// User management service for demonstrating business logic testing
    /// </summary>
    public class UserService
    {
        private readonly List<User> _users;

        public UserService()
        {
            _users = new List<User>();
        }

        public void AddUser(User user)
        {
            if (user == null)
            {
                throw new ArgumentNullException(nameof(user));
            }

            if (string.IsNullOrWhiteSpace(user.Username))
            {
                throw new ArgumentException("Username cannot be empty", nameof(user));
            }

            if (string.IsNullOrWhiteSpace(user.Email))
            {
                throw new ArgumentException("Email cannot be empty", nameof(user));
            }

            if (_users.Any(u => u.Username == user.Username))
            {
                throw new InvalidOperationException($"User with username '{user.Username}' already exists");
            }

            _users.Add(user);
        }

        public User GetUser(string username)
        {
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username cannot be empty", nameof(username));
            }

            return _users.FirstOrDefault(u => u.Username == username);
        }

        public List<User> GetAllUsers()
        {
            return _users.ToList();
        }

        public bool DeleteUser(string username)
        {
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username cannot be empty", nameof(username));
            }

            var user = _users.FirstOrDefault(u => u.Username == username);
            if (user != null)
            {
                _users.Remove(user);
                return true;
            }
            return false;
        }

        public void UpdateUser(string username, User updatedUser)
        {
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username cannot be empty", nameof(username));
            }

            if (updatedUser == null)
            {
                throw new ArgumentNullException(nameof(updatedUser));
            }

            var user = _users.FirstOrDefault(u => u.Username == username);
            if (user == null)
            {
                throw new InvalidOperationException($"User '{username}' not found");
            }

            user.Email = updatedUser.Email;
            user.FullName = updatedUser.FullName;
            user.IsActive = updatedUser.IsActive;
        }

        public int GetUserCount()
        {
            return _users.Count;
        }

        public List<User> GetActiveUsers()
        {
            return _users.Where(u => u.IsActive).ToList();
        }
    }

    public class User
    {
        public string Username { get; set; }
        public string Email { get; set; }
        public string FullName { get; set; }
        public bool IsActive { get; set; }

        public User()
        {
            IsActive = true;
        }

        public User(string username, string email, string fullName)
        {
            Username = username;
            Email = email;
            FullName = fullName;
            IsActive = true;
        }
    }
}
