using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Application.UseCases;

public class UpdateEmploymentContractUseCase
{
    private readonly IEmploymentContractRepository _contractRepository;

    public UpdateEmploymentContractUseCase(IEmploymentContractRepository contractRepository)
    {
        _contractRepository = contractRepository;
    }

    public async Task ExecuteAsync(int id, UpdateEmploymentContractDTO dto)
    {
        var existing = await _contractRepository.GetByIdAsync(id)
            ?? throw new KeyNotFoundException("El contrato indicado no existe.");

        existing.Update(
            institutionId: dto.InstitutionId,
            schoolYearId: dto.SchoolYearId,
            jobPositionId: dto.JobPositionId,
            areaId: dto.AreaId,
            startDate: dto.StartDate,
            endDate: dto.EndDate,
            salary: dto.Salary);

        await _contractRepository.UpdateAsync(existing);
    }
}
