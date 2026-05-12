using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class CreateEnrollmentUseCase
{
    private readonly IEnrollmentRepository _enrollmentRepository;

    public CreateEnrollmentUseCase(IEnrollmentRepository enrollmentRepository)
    {
        _enrollmentRepository = enrollmentRepository;
    }

    public async Task<DEnrollment> ExecuteAsync(EnrollStudentDTO dto)
    {
        var existing = await _enrollmentRepository.GetByStudentIdAndYearAsync(dto.StudentId, dto.SchoolYearId);
        if (existing != null)
            throw new InvalidOperationException("El estudiante ya tiene una matrícula en el año escolar indicado.");

        var sectionId = await _enrollmentRepository.FindSectionIdAsync(
            dto.SchoolYearId, dto.GradeId, dto.ShiftId, dto.SectionId);

        if (sectionId == null)
            throw new KeyNotFoundException("La sección indicada no existe o no corresponde al año escolar, grado y turno especificados.");

        return await _enrollmentRepository.CreateAsync(dto.StudentId, sectionId.Value, dto.SchoolFeeConceptId, dto.SchoolYearId, dto.PreviousSchool);
    }
}
