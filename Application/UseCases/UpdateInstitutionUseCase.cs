using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateInstitutionUseCase
{
    private readonly IInstitutionRepository _institutionRepository;

    public UpdateInstitutionUseCase(IInstitutionRepository institutionRepository)
    {
        _institutionRepository = institutionRepository;
    }

    public async Task ExecuteAsync(int id, CreateInstitutionDTO dto)
    {
        if (!await _institutionRepository.ExistsAsync(id))
            throw new KeyNotFoundException("Institución no encontrada.");

        if (await _institutionRepository.RucExistsAsync(dto.Ruc, excludeId: id))
            throw new InvalidOperationException("Ya existe otra institución registrada con ese RUC.");

        await _institutionRepository.UpdateAsync(id, dto);
    }
}
