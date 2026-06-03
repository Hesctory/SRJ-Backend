using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IAccountRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateAccountDTO dto);
    Task UpdateAsync(int id, CreateAccountDTO dto);
    Task<bool> DeleteAsync(int id);
}
