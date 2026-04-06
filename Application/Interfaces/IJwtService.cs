namespace SRJBackend.Application.Interfaces;

public interface IJwtService
{
    string GenerateToken(int userId, string email, IEnumerable<string> roles);
}
