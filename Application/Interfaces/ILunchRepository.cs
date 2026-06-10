using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILunchRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateLunchDTO dto);
    Task UpdateAsync(int id, CreateLunchDTO dto);
    Task<bool> DeleteAsync(int id);
}
