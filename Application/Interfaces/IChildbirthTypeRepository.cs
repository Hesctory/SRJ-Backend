using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IChildbirthTypeRepository
{
    Task<List<ChildbirthTypeDTO>> GetAllAsync();
}
