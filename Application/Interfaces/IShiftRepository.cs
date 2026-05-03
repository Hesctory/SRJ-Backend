using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IShiftRepository
{
    Task<(List<ShiftDTO> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<ShiftDTO?> GetByIdAsync(int id);
}
