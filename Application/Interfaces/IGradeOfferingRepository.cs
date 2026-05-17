using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IGradeOfferingRepository
{
    Task<bool> ExistsAsync(int id);
    Task<int> CreateAsync(CreateGradeOfferingDTO dto);
    Task UpdateAsync(int id, CreateGradeOfferingDTO dto);
    Task<bool> DeleteAsync(int id);
}
