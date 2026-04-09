using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IGenderRepository
{
    Task<List<GenderDTO>> GetAllAsync();
}
