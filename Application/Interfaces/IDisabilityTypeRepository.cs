using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IDisabilityTypeRepository
{
    Task<List<DisabilityTypeDTO>> GetAllAsync();
}
