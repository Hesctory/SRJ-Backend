using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILevelQueries
{
    Task<(List<LevelDTO> Items, int Total)> GetPagedAsync(int skip, int take);
    Task<LevelDTO?> GetByIdAsync(int id);
}
