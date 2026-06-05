using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IJobPositionRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateJobPositionDTO dto);
    Task UpdateAsync(int id, CreateJobPositionDTO dto);
    Task<bool> DeleteAsync(int id);
}
