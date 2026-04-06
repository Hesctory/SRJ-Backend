using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IAuthRepository
{
    Task<DUser?> GetUserByEmailAsync(string email);
    Task<string?> GetHashedPasswordByEmailAsync(string email);
}
