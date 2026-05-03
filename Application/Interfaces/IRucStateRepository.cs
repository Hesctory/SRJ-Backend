using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IRucStateRepository
{
    Task<List<RucStateDTO>> GetAllAsync();
}
