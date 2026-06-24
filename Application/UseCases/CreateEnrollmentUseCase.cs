using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Application.UseCases;

public class CreateEnrollmentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly IEnrollmentQueries _enrollmentQueries;
    private readonly IGradeOfferingShiftSectionRepository _sectionRepository;
    private readonly GenerateEnrollmentChargesUseCase _generateCharges;
    private readonly IUnitOfWork _unitOfWork;

    public CreateEnrollmentUseCase(
        IEnrollmentRepository enrollmentRepository,
        IEnrollmentQueries enrollmentQueries,
        IGradeOfferingShiftSectionRepository sectionRepository,
        GenerateEnrollmentChargesUseCase generateCharges,
        IUnitOfWork unitOfWork)
    {
        _enrollmentRepository = enrollmentRepository;
        _enrollmentQueries = enrollmentQueries;
        _sectionRepository = sectionRepository;
        _generateCharges = generateCharges;
        _unitOfWork = unitOfWork;
    }

    public async Task<DEnrollment> ExecuteAsync(EnrollStudentDTO dto)
    {
        var existing = await _enrollmentRepository.GetByStudentIdAndYearAsync(dto.StudentId, dto.SchoolYearId);
        if (existing != null)
            throw new InvalidOperationException("El estudiante ya tiene una matrícula en el año escolar indicado.");

        var sectionId = await _sectionRepository.FindValidSectionIdAsync(
            dto.SchoolYearId, dto.GradeId, dto.ShiftId, dto.SectionId);

        if (sectionId == null)
            throw new KeyNotFoundException("La sección indicada no existe o no corresponde al año escolar, grado y turno especificados.");

        var placement = new AcademicPlacement(dto.LevelId, dto.GradeId, dto.ShiftId, sectionId.Value);
        var hasValid = await _enrollmentQueries.HasValidEnrollmentsAsync(dto.StudentId);

        await _unitOfWork.BeginAsync();
        try
        {
            var enrollment = await _enrollmentRepository.CreateAsync(
                dto.StudentId, placement, dto.SchoolFeeConceptId, dto.SchoolYearId, dto.PreviousSchool, isNew: !hasValid);

            // Re-enrollment → enrollment debt only (admission only when isNew, i.e. no prior valid enrollment).
            await _generateCharges.ExecuteAsync(enrollment, isNew: !hasValid, createdBy: null);

            await _unitOfWork.CommitAsync();
            return enrollment;
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }
    }
}
