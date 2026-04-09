using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IDisabilityDegreeRepository
{
    Task<List<DisabilityDegreeDTO>> GetAllAsync();
}
