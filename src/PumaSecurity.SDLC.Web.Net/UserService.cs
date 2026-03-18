namespace PumaSecurity.SDLC.Web.Net;

using System.Data.SqlClient;
using System.Security.Cryptography;
using System.Text;
using System.Diagnostics;

/// <summary>
/// User management service for demonstrating business logic testing
/// </summary>
public class UserService
{
    private readonly List<User> _users;
    
    // INTENTIONAL SECURITY ISSUE: Hard-coded credentials for Semgrep to detect
    private const string DatabasePassword = "P@ssw0rd123!";
    private const string ApiKey = "sk-1234567890abcdef";

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

    public User? GetUser(string username)
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

    // INTENTIONAL SECURITY ISSUE: SQL Injection vulnerability for Semgrep to detect
    public User? SearchUserByEmail(string email, SqlConnection connection)
    {
        // Vulnerable: String concatenation in SQL query
        string query = "SELECT * FROM Users WHERE Email = '" + email + "'";
        var command = new SqlCommand(query, connection);
        
        // This would execute the vulnerable query
        // var reader = command.ExecuteReader();
        // ... process results
        
        return null; // Simplified for demo
    }

    // INTENTIONAL SECURITY ISSUE: Weak cryptography (MD5) for Semgrep to detect
    public string HashPassword(string password)
    {
        using (var md5 = MD5.Create())
        {
            byte[] inputBytes = Encoding.UTF8.GetBytes(password);
            byte[] hashBytes = md5.ComputeHash(inputBytes);
            
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < hashBytes.Length; i++)
            {
                sb.Append(hashBytes[i].ToString("x2"));
            }
            return sb.ToString();
        }
    }

    // INTENTIONAL SECURITY ISSUE: Command injection for Semgrep to detect
    public string ExecuteUserCommand(string username)
    {
        // Vulnerable: User input directly in shell command
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = "/c echo " + username,
                RedirectStandardOutput = true,
                UseShellExecute = false
            }
        };
        
        process.Start();
        string result = process.StandardOutput.ReadToEnd();
        process.WaitForExit();
        
        return result;
    }
}

public class User
{
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
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
