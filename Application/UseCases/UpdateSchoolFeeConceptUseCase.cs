using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateSchoolFeeConceptUseCase
{
    private readonly ISchoolFeeConceptRepository _schoolFeeConceptRepository;

    public UpdateSchoolFeeConceptUseCase(ISchoolFeeConceptRepository schoolFeeConceptRepository)
    {
        _schoolFeeConceptRepository = schoolFeeConceptRepository;
    }

    public async Task ExecuteAsync(int id, CreateSchoolFeeConceptDTO dto)
    {
        if (await _schoolFeeConceptRepository.NameExistsAsync(dto.Name, excludeId: id))
            throw new InvalidOperationException("Ya existe un concepto de pago con ese nombre.");

        await _schoolFeeConceptRepository.UpdateAsync(id, dto);
    }
}
