using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class LevelQueries : ILevelQueries
{
    private readonly ILevelRepository _levelRepo;

    public LevelQueries(ILevelRepository levelRepo)
    {
        _levelRepo = levelRepo;
    }

    public Task<(List<LevelDTO> Items, int Total)> GetPagedAsync(int skip, int take)
        => _levelRepo.GetPagedAsync(skip, take);

    public Task<LevelDTO?> GetByIdAsync(int id)
        => _levelRepo.GetByIdAsync(id);
}
