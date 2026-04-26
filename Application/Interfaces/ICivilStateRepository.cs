using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ICivilStateRepository
{
    Task<List<CivilStateDTO>> GetAllAsync();
}
